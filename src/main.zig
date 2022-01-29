const std = @import("std");
const w4 = @import("w4.zig");
var prng: std.rand.DefaultPrng = undefined;
var random: std.rand.Random = undefined;

const word_list = @embedFile("sgb-words-sorted.txt");

export fn start() void {
    w4.PALETTE.* = .{
        0xdeeed6,
        0xdad45e,
        0x6daa2c,
        0x4e4a4e,
    };
    change_color(NORMAL);

    prng = std.rand.DefaultPrng.init(0);
    random = prng.random();
    game = Game.init();
}

var game: Game = undefined;

const WORD_LENGTH: usize = 5;
const GUESS_LENGTH: usize = 6;

// color schemes
const UNSPECIFIED: u16 = 0x40;
const NORMAL: u16 = 0x04;
const WRONG_SPOT: u16 = 0x24;
const CORRECT_SPOT: u16 = 0x31;
const ABSENT: u16 = 0x41;
const UNSPECIFIED_RECT: u16 = 0x40;
const NORMAL_RECT: u16 = 0x40;
const WRONG_SPOT_RECT: u16 = 0x22;
const CORRECT_SPOT_RECT: u16 = 0x33;
const ABSENT_RECT: u16 = 0x44;
const CURSOR_RECT: u16 = 0x30;

fn change_color(color: u16) void {
    w4.DRAW_COLORS.* = color;
}

export fn to_be_removed() void {
    var i: usize = 1;
    while (i < WORD_LENGTH) : (i += 1) {
        var j: usize = 1;
        while (j < WORD_LENGTH) : (j += 1) {
            w4.DRAW_COLORS.* = @intCast(u16, j) | (@intCast(u16, i) << 4);
            w4.rect(10 * @intCast(i32, i), 10 * @intCast(i32, j), 10, 10);
        }
    }
    change_color(NORMAL);
    w4.text("normal", 60, 10);
    change_color(WRONG_SPOT);
    w4.text("wrong spot", 60, 20);
    change_color(CORRECT_SPOT);
    w4.text("correct spot", 60, 30);
    change_color(ABSENT);
    w4.text("> ABSENT", 60, 40);
    change_color(NORMAL);
    if (w4.GAMEPAD1.* & w4.BUTTON_1 != 0) {
        change_color(ABSENT);
    } else {
        change_color(NORMAL);
    }
    w4.rect(0, 0, 5, 5);
    if (w4.GAMEPAD1.* & w4.BUTTON_2 != 0) {
        change_color(ABSENT);
    } else {
        change_color(NORMAL);
    }
    w4.rect(5, 0, 5, 5);
    change_color(NORMAL);
}

export fn update() void {
    game.update();
    game.draw();
}

const Game = struct {
    lingword: Lingword,

    fn init() Game {
        var g = Game{
            .lingword = Lingword.init(),
        };
        return g;
    }

    fn update(self: *Game) void {
        self.lingword.update();
    }

    fn draw(self: *Game) void {
        self.lingword.draw();
    }

    fn input(self: *Game) void {
        self.lingword.input();
    }
};

const guesses_x_offset = 40;
const guesses_y_offset = 5;
const kbd_x_offset = 1;
const kbd_y_offset = 110;
const kbd_row_spacing = 16;
const kbd_row_1 = "qwertyuiop";
const kbd_row_2 = "asdfghjkl";
const kbd_row_3 = "zxcvbnm";

const LingwordState = enum {
    NotReady,
    PlayerInput,
    ReadyToSubmit,
    AssessGuess,
    Victory,
    Loss,
};

const LetterStatus = enum {
    Unknown,
    Absent,
    Present,
    CorrectSpot,
};

const Lingword = struct {
    word_to_guess: [WORD_LENGTH:0]u8,
    guesses: [GUESS_LENGTH][WORD_LENGTH:0]u8,
    guesses_assessment: [GUESS_LENGTH][WORD_LENGTH]LetterStatus,
    current_guess: usize,
    letter_statuses: [26]LetterStatus,
    state: LingwordState,
    cursor_x: isize,
    cursor_y: isize,
    previous_input: u8,

    fn init() Lingword {
        var w = Lingword{
            .word_to_guess = undefined,
            .guesses = undefined,
            .guesses_assessment = undefined,
            .current_guess = 0,
            .letter_statuses = undefined,
            .state = LingwordState.NotReady,
            .cursor_x = 0,
            .cursor_y = 0,
            .previous_input = 0,
        };
        return w;
    }

    fn reset_random(self: *Lingword) void {
        const index = random.intRangeLessThan(usize, 0, word_list.len / 6);
        const slice = word_list[(6 * index)..];
        self.reset(slice);
    }

    fn reset(self: *Lingword, answer: []const u8) void {
        var i: usize = 0;
        while (i < WORD_LENGTH) : (i += 1) {
            self.word_to_guess[i] = answer[i];
        }
        self.current_guess = 0;
        i = 0;
        while (i < GUESS_LENGTH) : (i += 1) {
            var j: usize = 0;
            while (j < WORD_LENGTH) : (j += 1) {
                self.guesses[i][j] = '.';
            }
        }
        i = 0;
        while (i < GUESS_LENGTH) : (i += 1) {
            var j: usize = 0;
            while (j < WORD_LENGTH) : (j += 1) {
                self.guesses_assessment[i][j] = LetterStatus.Unknown;
            }
        }
        i = 0;
        while (i < self.letter_statuses.len) : (i += 1) {
            self.letter_statuses[i] = LetterStatus.Unknown;
        }

        self.state = LingwordState.PlayerInput;
    }

    fn guess_is_complete(self: *Lingword) bool {
        var j: usize = 0;
        while (j < WORD_LENGTH) : (j += 1) {
            if (self.guesses[self.current_guess][j] == '.') {
                return false;
            }
        }
        return true;
    }

    fn add_letter(self: *Lingword, letter: u8) void {
        var j: usize = 0;
        while (j < WORD_LENGTH) : (j += 1) {
            if (self.guesses[self.current_guess][j] == '.') {
                self.guesses[self.current_guess][j] = letter;
                return;
            }
        }
    }

    fn remove_last_letter(self: *Lingword) void {
        var j: isize = 4;
        while (j >= 0 and self.guesses[self.current_guess][@intCast(usize, j)] == '.') {
            j -= 1;
        }
        if (j >= 0) {
            self.guesses[self.current_guess][@intCast(usize, j)] = '.';
        }
    }

    fn get_keyboard_letter(self: *Lingword) u8 {
        _ = self;
        if (self.cursor_y == 0) {
            return kbd_row_1[@intCast(usize, self.cursor_x)];
        }
        if (self.cursor_y == 1) {
            return kbd_row_2[@intCast(usize, self.cursor_x)];
        }
        if (self.cursor_y == 2) {
            return kbd_row_3[@intCast(usize, self.cursor_x)];
        }
        return '.';
    }

    fn button_released(self: *Lingword, button: u8) bool {
        return w4.GAMEPAD1.* & button == 0 and self.previous_input & button != 0;
    }

    fn normalize_cursor_x(self: *Lingword) void {
        if (self.cursor_x < 0) {
            if (self.cursor_y == 0) {
                self.cursor_x = kbd_row_1.len - 1;
            }
            if (self.cursor_y == 1) {
                self.cursor_x = kbd_row_2.len - 1;
            }
            if (self.cursor_y == 2) {
                self.cursor_x = kbd_row_3.len - 1;
            }
        }
        if (self.cursor_y == 0 and self.cursor_x >= kbd_row_1.len) {
            self.cursor_x = 0;
        }
        if (self.cursor_y == 1 and self.cursor_x >= kbd_row_2.len) {
            self.cursor_x = 0;
        }
        if (self.cursor_y == 2 and self.cursor_x >= kbd_row_3.len) {
            self.cursor_x = 0;
        }
    }

    fn input_kbd(self: *Lingword) void {
        const max_row = 3;
        if (self.button_released(w4.BUTTON_LEFT)) {
            self.cursor_x -= 1;
            self.normalize_cursor_x();
        }
        if (self.button_released(w4.BUTTON_RIGHT)) {
            self.cursor_x += 1;
            self.normalize_cursor_x();
        }
        if (self.button_released(w4.BUTTON_UP)) {
            self.cursor_y -= 1;
            if (self.cursor_y < 0) {
                self.cursor_y = max_row - 1;
            }
            self.normalize_cursor_x();
        }
        if (self.button_released(w4.BUTTON_DOWN)) {
            self.cursor_y += 1;
            if (self.cursor_y == max_row) {
                self.cursor_y = 0;
            }
            self.normalize_cursor_x();
        }
        if (self.button_released(w4.BUTTON_1)) {
            self.add_letter(self.get_keyboard_letter());
            if (self.guess_is_complete()) {
                self.state = LingwordState.ReadyToSubmit;
            }
        }
        if (self.button_released(w4.BUTTON_2)) {
            self.remove_last_letter();
        }
    }

    fn input_submit(self: *Lingword) void {
        if (self.button_released(w4.BUTTON_1)) {
            self.state = LingwordState.AssessGuess;
        }
        if (self.button_released(w4.BUTTON_2)) {
            self.remove_last_letter();
            self.state = LingwordState.PlayerInput;
        }
    }

    fn input_end(self: *Lingword) void {
        if (self.button_released(w4.BUTTON_1) or self.button_released(w4.BUTTON_2)) {
            self.state = LingwordState.NotReady;
        }
    }

    fn input(self: *Lingword) void {
        switch (self.state) {
            LingwordState.NotReady => {},
            LingwordState.ReadyToSubmit => {
                self.input_submit();
            },
            LingwordState.PlayerInput => {
                self.input_kbd();
            },
            LingwordState.AssessGuess => {},
            LingwordState.Victory => {
                self.input_end();
            },
            LingwordState.Loss => {
                self.input_end();
            },
        }
        self.previous_input = w4.GAMEPAD1.*;
    }

    fn assess_guess_colors(self: *Lingword) void {
        var i: usize = 0;
        var word_to_guess: [WORD_LENGTH:0]u8 = undefined;
        while (i < WORD_LENGTH) : (i += 1) {
            self.guesses_assessment[self.current_guess][i] = LetterStatus.Absent;
            word_to_guess[i] = self.word_to_guess[i];
        }
        for (self.guesses[self.current_guess]) |letter, idx| {
            self.letter_statuses[letter - 'a'] = LetterStatus.Absent;
            if (word_to_guess[idx] == letter) {
                self.guesses_assessment[self.current_guess][idx] = LetterStatus.CorrectSpot;
                self.letter_statuses[letter - 'a'] = LetterStatus.Present;
                word_to_guess[idx] = '.';
            }
        }
        for (self.guesses[self.current_guess]) |letter, idx| {
            var j: usize = 0;
            while (j < WORD_LENGTH) : (j += 1) {
                if (word_to_guess[j] == letter) {
                    self.guesses_assessment[self.current_guess][idx] = LetterStatus.Present;
                    self.letter_statuses[letter - 'a'] = LetterStatus.Present;
                    word_to_guess[j] = '.';
                }
            }
        }
    }

    fn assess_guess(self: *Lingword) void {
        self.assess_guess_colors();
        if (self.guess_is_correct()) {
            self.state = LingwordState.Victory;
        } else if (self.current_guess == 5) {
            self.state = LingwordState.Loss;
        } else {
            self.state = LingwordState.PlayerInput;
        }
        self.current_guess += 1; // this allows the last guess to be colored
    }

    fn update(self: *Lingword) void {
        self.input();

        switch (self.state) {
            LingwordState.AssessGuess => {
                self.assess_guess();
            },
            LingwordState.NotReady => {
                self.reset_random();
            },
            else => {},
        }

        self.draw();
    }
    //// Drawing functions ////

    fn draw_letter_rect(x: i32, y: i32) void {
        const old_color = w4.DRAW_COLORS.*;
        //const rect_color = (old_color & 0xf) << 8 | (old_color & 0xf0) >> 8;
        const rect_color = switch (old_color) {
            UNSPECIFIED => UNSPECIFIED_RECT,
            NORMAL => NORMAL_RECT,
            WRONG_SPOT => WRONG_SPOT_RECT,
            CORRECT_SPOT => CORRECT_SPOT_RECT,
            ABSENT => ABSENT_RECT,
            else => UNSPECIFIED_RECT,
        };
        change_color(rect_color);
        w4.rect(x, y, 14, 14);
        change_color(old_color);
    }

    fn draw_letter(letter: u8, x: i32, y: i32) void {
        const str =
            switch (letter) {
            'a' => "A",
            'b' => "B",
            'c' => "C",
            'd' => "D",
            'e' => "E",
            'f' => "F",
            'g' => "G",
            'h' => "H",
            'i' => "I",
            'j' => "J",
            'k' => "K",
            'l' => "L",
            'm' => "M",
            'n' => "N",
            'o' => "O",
            'p' => "P",
            'q' => "Q",
            'r' => "R",
            's' => "S",
            't' => "T",
            'u' => "U",
            'v' => "V",
            'w' => "W",
            'x' => "X",
            'y' => "Y",
            'z' => "Z",
            else => " ",
        };
        draw_letter_rect(x, y);
        w4.text(str, x + 3, y + 3);
    }

    fn answer_contains_letter(self: *Lingword, letter: u8) bool {
        for (self.word_to_guess) |l| {
            if (l == letter) {
                return true;
            }
        }
        return false;
    }

    fn guess_is_correct(self: *Lingword) bool {
        var i: usize = 0;
        while (i < WORD_LENGTH) : (i += 1) {
            if (self.word_to_guess[i] != self.guesses[self.current_guess][i]) {
                return false;
            }
        }
        return true;
    }

    fn letter_from_status(letter_status: LetterStatus) u16 {
        switch (letter_status) {
            LetterStatus.CorrectSpot => {
                return CORRECT_SPOT;
            },
            LetterStatus.Present => {
                return WRONG_SPOT;
            },
            LetterStatus.Absent => {
                return ABSENT;
            },
            LetterStatus.Unknown => {
                return NORMAL;
            },
        }
    }

    fn draw_guesses(self: *Lingword) void {
        var i: usize = 0;
        while (i < GUESS_LENGTH) : (i += 1) {
            var j: usize = 0;
            while (j < WORD_LENGTH) : (j += 1) {
                const letter = self.guesses[i][j];
                const x = guesses_x_offset + @intCast(i32, j) * 16;
                const y = guesses_y_offset + @intCast(i32, i) * 16;
                if (letter == '.') {
                    change_color(UNSPECIFIED);
                    draw_letter_rect(x, y);
                } else {
                    const color = letter_from_status(self.guesses_assessment[i][j]);
                    change_color(color);
                    draw_letter(letter, x, y);
                }
            }
        }
    }

    fn draw_keyboard(self: *Lingword) void {
        var i: usize = 0;
        while (i < kbd_row_1.len) : (i += 1) {
            const color = letter_from_status(self.letter_statuses[kbd_row_1[i] - 'a']);
            change_color(color);
            draw_letter(kbd_row_1[i], kbd_x_offset + @intCast(i32, i) * 16, kbd_y_offset);
        }
        i = 0;
        while (i < kbd_row_2.len) : (i += 1) {
            const color = letter_from_status(self.letter_statuses[kbd_row_2[i] - 'a']);
            change_color(color);
            draw_letter(kbd_row_2[i], kbd_x_offset + @intCast(i32, i) * 16, kbd_y_offset + 1 * kbd_row_spacing);
        }
        i = 0;
        while (i < kbd_row_3.len) : (i += 1) {
            const color = letter_from_status(self.letter_statuses[kbd_row_3[i] - 'a']);
            change_color(color);
            draw_letter(kbd_row_3[i], kbd_x_offset + @intCast(i32, i) * 16, kbd_y_offset + 2 * kbd_row_spacing);
        }
    }

    fn draw_cursor(self: *Lingword) void {
        change_color(CURSOR_RECT);
        w4.rect(self.cursor_x * 16 + kbd_x_offset - 1, self.cursor_y * 16 + kbd_y_offset - 1, 16, 16);
        w4.rect(self.cursor_x * 16 + kbd_x_offset, self.cursor_y * 16 + kbd_y_offset, 14, 14);
    }

    fn draw_submit_guess(self: *Lingword) void {
        _ = self;
        change_color(NORMAL);
        w4.text("Press", guesses_x_offset - 16, kbd_y_offset);
        w4.text("BTN1 to submit", guesses_x_offset - 8, kbd_y_offset + 10);
        w4.text("BTN2 to edit", guesses_x_offset - 8, kbd_y_offset + 20);
    }

    fn draw_victory(self: *Lingword) void {
        _ = self;
        change_color(NORMAL);
        w4.text("Victory !!", guesses_x_offset, kbd_y_offset);
    }

    fn draw_loss(self: *Lingword) void {
        _ = self;
        change_color(NORMAL);
        w4.text("You lose..", guesses_x_offset, kbd_y_offset);
        w4.text("Answer was", guesses_x_offset, kbd_y_offset + 10);
        var i: usize = 0;
        change_color(CORRECT_SPOT);
        while (i < WORD_LENGTH) : (i += 1) {
            draw_letter(self.word_to_guess[i], guesses_x_offset + @intCast(i32, i) * 16, kbd_y_offset + 30);
        }
    }

    fn draw(self: *Lingword) void {
        switch (self.state) {
            LingwordState.NotReady => {},
            LingwordState.PlayerInput => {
                self.draw_guesses();
                self.draw_keyboard();
                self.draw_cursor();
            },
            LingwordState.ReadyToSubmit => {
                self.draw_guesses();
                self.draw_submit_guess();
            },
            LingwordState.AssessGuess => {},
            LingwordState.Victory => {
                self.draw_guesses();
                self.draw_victory();
            },
            LingwordState.Loss => {
                self.draw_guesses();
                self.draw_loss();
            },
        }
    }
};
