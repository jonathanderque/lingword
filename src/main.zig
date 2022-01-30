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
const WORD_LIST_ENTRY_LENGTH: usize = 6;
const GUESS_LENGTH: usize = 6;

const anim_step_duration = 300;

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

var previous_input: u8 = 0;
fn button_released(button: u8) bool {
    return w4.GAMEPAD1.* & button == 0 and previous_input & button != 0;
}

fn change_color(color: u16) void {
    w4.DRAW_COLORS.* = color;
}

var sound_flag: bool = false;
fn play_tone_from_letter_status(status: LetterStatus) void {
    const tone: u32 = switch (status) {
        LetterStatus.Absent => 200,
        LetterStatus.Present => 400,
        LetterStatus.CorrectSpot => 740 | (860 << 16),
        else => 740,
    };
    if (sound_flag) {
        w4.tone(tone, 4, 80, w4.TONE_PULSE2);
    }
}

fn draw_letter_rect(color: u16, x: i32, y: i32) void {
    const rect_color = switch (color) {
        UNSPECIFIED => UNSPECIFIED_RECT,
        NORMAL => NORMAL_RECT,
        WRONG_SPOT => WRONG_SPOT_RECT,
        CORRECT_SPOT => CORRECT_SPOT_RECT,
        ABSENT => ABSENT_RECT,
        else => UNSPECIFIED_RECT,
    };
    change_color(rect_color);
    w4.rect(x, y, 14, 14);
}

fn draw_letter(letter: u8, color: u16, x: i32, y: i32) void {
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
    draw_letter_rect(color, x, y);
    change_color(color);
    w4.text(str, x + 3, y + 3);
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

const GameState = enum {
    TitleScreen,
    Lingword,
};

const Game = struct {
    state: GameState,
    title: TitleScreen,
    lingword: Lingword,

    fn init() Game {
        var g = Game{
            .state = GameState.TitleScreen,
            .lingword = Lingword.init(),
            .title = TitleScreen.init(),
        };
        return g;
    }

    fn update(self: *Game) void {
        switch (self.state) {
            GameState.TitleScreen => {
                if (self.title.state == TitleScreenState.ToGame) {
                    self.lingword.state = LingwordState.NotReady;
                    self.state = GameState.Lingword;
                } else {
                    self.title.update(16);
                }
            },
            GameState.Lingword => {
                if (self.lingword.state == LingwordState.BackToMenu) {
                    self.state = GameState.TitleScreen;
                    self.title.reset();
                } else {
                    self.lingword.update(16);
                }
            },
        }
        previous_input = w4.GAMEPAD1.*;
        // cycle through on each frame as the RNG is not properly seeded
        _ = random.intRangeLessThan(usize, 0, word_list.len / WORD_LIST_ENTRY_LENGTH);
    }

    fn draw(self: *Game) void {
        switch (self.state) {
            GameState.TitleScreen => {
                self.title.draw_title_screen();
            },
            GameState.Lingword => {
                self.lingword.draw();
            },
        }
    }
};

const TitleScreenState = enum {
    ActiveMenu,
    ToGame,
};

const TitleScreen = struct {
    state: TitleScreenState,
    title_ms: u32,
    cursor_y: usize,

    pub fn init() TitleScreen {
        return TitleScreen{
            .state = TitleScreenState.ActiveMenu,
            .title_ms = 0,
            .cursor_y = 0,
        };
    }

    fn reset(self: *TitleScreen) void {
        self.state = TitleScreenState.ActiveMenu;
        self.title_ms = 0;
        self.cursor_y = 0;
    }

    fn draw_title_screen(self: *TitleScreen) void {
        const title = "lingword";
        const colors = [_]u16{
            CORRECT_SPOT,
            ABSENT,
            ABSENT,
            ABSENT,
            WRONG_SPOT,
            ABSENT,
            ABSENT,
            ABSENT,
        };
        for (title) |letter, i| {
            const max_index = self.title_ms / anim_step_duration;
            const color = if (i < max_index) colors[i] else NORMAL;
            draw_letter(letter, color, 16 * @intCast(i32, 1 + i), 60);
        }
        change_color(NORMAL);
        if (self.title_ms > anim_step_duration * title.len) {
            if (self.cursor_y == 0) {
                w4.text("> start", 16, 120);
            } else {
                w4.text("  start", 16, 120);
            }
            if (self.cursor_y == 1) {
                if (sound_flag) {
                    w4.text("> sound: <on>", 16, 130);
                } else {
                    w4.text("> sound: <off>", 16, 130);
                }
            } else {
                if (sound_flag) {
                    w4.text("  sound: <on>", 16, 130);
                } else {
                    w4.text("  sound: <off>", 16, 130);
                }
            }
        }
    }

    fn update(self: *TitleScreen, ms: u32) void {
        self.input();
        self.title_ms += ms;
    }

    fn input(self: *TitleScreen) void {
        if (button_released(w4.BUTTON_DOWN) or button_released(w4.BUTTON_UP)) {
            if (self.cursor_y == 1) {
                self.cursor_y = 0;
            } else {
                self.cursor_y = 1;
            }
        }
        if (button_released(w4.BUTTON_1)) {
            if (self.cursor_y == 0) {
                self.state = TitleScreenState.ToGame;
            }
            if (self.cursor_y == 1) {
                sound_flag = !sound_flag;
            }
        }
    }
};

const guesses_x_offset = 40;
const guesses_y_offset = 5;
const kbd_x_offset: [3]i32 = [_]i32{ 1, 11, 21 };
const kbd_y_offset = 110;
const kbd_row_spacing = 16;
const kbd_row_1 = "qwertyuiop";
const kbd_row_2 = "asdfghjkl";
const kbd_row_3 = "zxcvbnm";

const LingwordState = enum {
    BackToMenu,
    NotReady,
    PlayerInput,
    ReadyToSubmit,
    AssessGuess,
    RevealGuess,
    UnknownWord,
    Victory, // include End in the same screen
    Loss,
    End,
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
    reveal_timer: u32,
    reveal_step: usize,

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
            .reveal_timer = 0,
            .reveal_step = 0,
        };
        return w;
    }

    fn reset_random(self: *Lingword) void {
        const index = random.intRangeLessThan(usize, 0, word_list.len / WORD_LIST_ENTRY_LENGTH);
        const slice = word_list[(WORD_LIST_ENTRY_LENGTH * index)..];
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
        if (button_released(w4.BUTTON_LEFT)) {
            self.cursor_x -= 1;
            self.normalize_cursor_x();
        }
        if (button_released(w4.BUTTON_RIGHT)) {
            self.cursor_x += 1;
            self.normalize_cursor_x();
        }
        if (button_released(w4.BUTTON_UP)) {
            self.cursor_y -= 1;
            if (self.cursor_y < 0) {
                self.cursor_y = max_row - 1;
            }
            self.normalize_cursor_x();
        }
        if (button_released(w4.BUTTON_DOWN)) {
            self.cursor_y += 1;
            if (self.cursor_y == max_row) {
                self.cursor_y = 0;
            }
            self.normalize_cursor_x();
        }
        if (button_released(w4.BUTTON_1)) {
            self.add_letter(self.get_keyboard_letter());
            if (self.guess_is_complete()) {
                self.state = LingwordState.ReadyToSubmit;
            }
        }
        if (button_released(w4.BUTTON_2)) {
            self.remove_last_letter();
        }
    }

    fn input_submit(self: *Lingword) void {
        if (button_released(w4.BUTTON_1)) {
            self.state = LingwordState.AssessGuess;
        }
        if (button_released(w4.BUTTON_2)) {
            self.remove_last_letter();
            self.state = LingwordState.PlayerInput;
        }
    }

    fn input_loss(self: *Lingword) void {
        if (button_released(w4.BUTTON_1) or button_released(w4.BUTTON_2)) {
            self.state = LingwordState.End;
        }
    }

    fn input_end(self: *Lingword) void {
        if (button_released(w4.BUTTON_1)) {
            self.state = LingwordState.NotReady;
        }
        if (button_released(w4.BUTTON_2)) {
            self.state = LingwordState.BackToMenu;
        }
    }

    fn input_unknown_word(self: *Lingword) void {
        if (button_released(w4.BUTTON_1) or button_released(w4.BUTTON_2)) {
            self.state = LingwordState.PlayerInput;
        }
    }

    fn input(self: *Lingword) void {
        switch (self.state) {
            LingwordState.BackToMenu => {},
            LingwordState.NotReady => {},
            LingwordState.ReadyToSubmit => {
                self.input_submit();
            },
            LingwordState.PlayerInput => {
                self.input_kbd();
            },
            LingwordState.AssessGuess => {},
            LingwordState.RevealGuess => {},
            LingwordState.UnknownWord => {
                self.input_unknown_word();
            },
            LingwordState.Victory => {
                self.input_end();
            },
            LingwordState.Loss => {
                self.input_loss();
            },
            LingwordState.End => {
                self.input_end();
            },
        }
    }

    fn assess_guess_colors(self: *Lingword) void {
        var i: usize = 0;
        var word_to_guess: [WORD_LENGTH:0]u8 = undefined;
        while (i < WORD_LENGTH) : (i += 1) {
            self.guesses_assessment[self.current_guess][i] = LetterStatus.Absent;
            word_to_guess[i] = self.word_to_guess[i];
        }
        for (self.guesses[self.current_guess]) |letter, idx| {
            if (self.letter_statuses[letter - 'a'] == LetterStatus.Unknown) {
                self.letter_statuses[letter - 'a'] = LetterStatus.Absent;
            }
            if (word_to_guess[idx] == letter) {
                self.guesses_assessment[self.current_guess][idx] = LetterStatus.CorrectSpot;
                self.letter_statuses[letter - 'a'] = LetterStatus.Present;
                word_to_guess[idx] = '.';
            }
        }
        for (self.guesses[self.current_guess]) |letter, idx| {
            var j: usize = 0;
            while (j < WORD_LENGTH) : (j += 1) {
                if (word_to_guess[j] == letter and self.guesses_assessment[self.current_guess][idx] != LetterStatus.CorrectSpot) {
                    self.guesses_assessment[self.current_guess][idx] = LetterStatus.Present;
                    self.letter_statuses[letter - 'a'] = LetterStatus.Present;
                    word_to_guess[j] = '.';
                }
            }
        }
    }

    fn wordlist_contains_guess(self: *Lingword) bool {
        var low: usize = 0;
        const word_list_len = word_list.len / WORD_LIST_ENTRY_LENGTH;
        var high: usize = word_list_len - 1;
        var idx: usize = (low + high) / 2;
        while (low < high - 1) {
            var i: usize = 0;
            var cmp: i32 = 0;
            while (i < WORD_LENGTH) : (i += 1) {
                if (cmp == 0) {
                    cmp = @intCast(i32, self.guesses[self.current_guess][i]) - @intCast(i32, word_list[idx * WORD_LIST_ENTRY_LENGTH + i]);
                }
            }
            if (cmp < 0) {
                high = idx;
            } else if (cmp > 0) {
                low = idx;
            } else {
                return true;
            }
            idx = (low + high) / 2;
        }
        return false;
    }

    fn assess_guess(self: *Lingword) void {
        if (self.wordlist_contains_guess() == false) {
            self.state = LingwordState.UnknownWord;
            return;
        }
        self.assess_guess_colors();
        self.state = LingwordState.RevealGuess;
        self.reveal_timer = 0;
        self.reveal_step = 0;
    }

    fn reveal_guess(self: *Lingword, ms: u32) void {
        self.reveal_timer += ms;

        if (self.reveal_timer < 6 * anim_step_duration) {
            const new_step = self.reveal_timer / anim_step_duration;
            if (new_step != self.reveal_step) {
                play_tone_from_letter_status(self.guesses_assessment[self.current_guess][new_step - 1]);
                self.reveal_step = new_step;
            }
            return;
        }
        if (self.guess_is_correct()) {
            self.state = LingwordState.Victory;
        } else if (self.current_guess == 5) {
            self.state = LingwordState.Loss;
        } else {
            self.state = LingwordState.PlayerInput;
        }
        self.current_guess += 1; // this allows the last guess to be colored
    }

    fn update(self: *Lingword, ms: u32) void {
        self.input();

        switch (self.state) {
            LingwordState.AssessGuess => {
                self.assess_guess();
            },
            LingwordState.RevealGuess => {
                self.reveal_guess(ms);
            },
            LingwordState.NotReady => {
                self.reset_random();
            },
            else => {},
        }

        self.draw();
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

    //// Drawing functions ////
    fn draw_guess(self: *Lingword, guess_index: usize, reveal_until: usize) void {
        var j: usize = 0;
        while (j < WORD_LENGTH) : (j += 1) {
            const letter = self.guesses[guess_index][j];
            const x = guesses_x_offset + @intCast(i32, j) * 16;
            const y = guesses_y_offset + @intCast(i32, guess_index) * 16;
            if (letter == '.') {
                draw_letter_rect(UNSPECIFIED, x, y);
            } else {
                const color = if (j < reveal_until)
                    letter_from_status(self.guesses_assessment[guess_index][j])
                else
                    NORMAL;
                draw_letter(letter, color, x, y);
            }
        }
    }

    fn draw_guesses(self: *Lingword) void {
        var i: usize = 0;
        while (i < GUESS_LENGTH) : (i += 1) {
            self.draw_guess(i, WORD_LENGTH);
        }
    }

    fn draw_reveal_guesses(self: *Lingword) void {
        var i: usize = 0;
        while (i < GUESS_LENGTH) : (i += 1) {
            if (i != self.current_guess) {
                self.draw_guess(i, WORD_LENGTH);
            } else {
                self.draw_guess(i, self.reveal_timer / anim_step_duration);
            }
        }
    }

    fn draw_keyboard(self: *Lingword) void {
        var i: usize = 0;
        while (i < kbd_row_1.len) : (i += 1) {
            const color = letter_from_status(self.letter_statuses[kbd_row_1[i] - 'a']);
            draw_letter(kbd_row_1[i], color, kbd_x_offset[0] + @intCast(i32, i) * 16, kbd_y_offset);
        }
        i = 0;
        while (i < kbd_row_2.len) : (i += 1) {
            const color = letter_from_status(self.letter_statuses[kbd_row_2[i] - 'a']);
            draw_letter(kbd_row_2[i], color, kbd_x_offset[1] + @intCast(i32, i) * 16, kbd_y_offset + 1 * kbd_row_spacing);
        }
        i = 0;
        while (i < kbd_row_3.len) : (i += 1) {
            const color = letter_from_status(self.letter_statuses[kbd_row_3[i] - 'a']);
            draw_letter(kbd_row_3[i], color, kbd_x_offset[2] + @intCast(i32, i) * 16, kbd_y_offset + 2 * kbd_row_spacing);
        }
    }

    fn draw_cursor(self: *Lingword) void {
        change_color(CURSOR_RECT);
        const x_offset = kbd_x_offset[@intCast(usize, self.cursor_y)];
        w4.rect(self.cursor_x * 16 + x_offset - 1, self.cursor_y * 16 + kbd_y_offset - 1, 16, 16);
        w4.rect(self.cursor_x * 16 + x_offset, self.cursor_y * 16 + kbd_y_offset, 14, 14);
    }

    fn draw_submit_guess(self: *Lingword) void {
        _ = self;
        change_color(NORMAL);
        w4.text("Press", guesses_x_offset - 16, kbd_y_offset);
        w4.text("BTN1 to submit", guesses_x_offset - 8, kbd_y_offset + 10);
        w4.text("BTN2 to edit", guesses_x_offset - 8, kbd_y_offset + 20);
    }

    fn draw_end_buttons(self: *Lingword) void {
        _ = self;
        change_color(NORMAL);
        w4.text("BTN1 to continue", 8, kbd_y_offset + 20);
        w4.text("BTN2 to go to menu", 8, kbd_y_offset + 30);
    }

    fn draw_victory(self: *Lingword) void {
        _ = self;
        change_color(NORMAL);
        // self.current_guess should be incremented when this function is called
        // so the switch branches are one off. (ie. 1 to 6 instead of 0 to 5)
        switch (self.current_guess) {
            1 => {
                w4.text("How?!?...", guesses_x_offset, kbd_y_offset);
            },
            2 => {
                w4.text("Incredible!", guesses_x_offset, kbd_y_offset);
            },
            3 => {
                w4.text("Excellent!", guesses_x_offset, kbd_y_offset);
            },
            4 => {
                w4.text("Well Done!", guesses_x_offset, kbd_y_offset);
            },
            5 => {
                w4.text("Very Good!", guesses_x_offset, kbd_y_offset);
            },
            6 => {
                w4.text("Phew...", guesses_x_offset, kbd_y_offset);
            },
            else => {
                w4.text("Victory!", guesses_x_offset, kbd_y_offset);
            },
        }
        self.draw_end_buttons();
    }

    fn draw_loss(self: *Lingword) void {
        change_color(NORMAL);
        w4.text("You lose..", guesses_x_offset, kbd_y_offset);
        w4.text("Answer was", guesses_x_offset, kbd_y_offset + 10);
        var i: usize = 0;
        while (i < WORD_LENGTH) : (i += 1) {
            draw_letter(self.word_to_guess[i], CORRECT_SPOT, guesses_x_offset + @intCast(i32, i) * 16, kbd_y_offset + 30);
        }
    }

    fn draw_unknown_word(self: *Lingword) void {
        _ = self;
        change_color(NORMAL);
        w4.text("Unknown word", guesses_x_offset, kbd_y_offset);
    }

    fn draw(self: *Lingword) void {
        switch (self.state) {
            LingwordState.BackToMenu => {},
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
            LingwordState.RevealGuess => {
                self.draw_reveal_guesses();
            },
            LingwordState.UnknownWord => {
                self.draw_guesses();
                self.draw_unknown_word();
            },
            LingwordState.Victory => {
                self.draw_guesses();
                self.draw_victory();
            },
            LingwordState.Loss => {
                self.draw_guesses();
                self.draw_loss();
            },
            LingwordState.End => {
                self.draw_guesses();
                self.draw_end_buttons();
            },
        }
    }
};
