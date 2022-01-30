# Lingword

Lingword is word guessing game similar to Lingo/Wordle written in [Zig](https://ziglang.org) for the [WASM-4](https://wasm4.org/) fantasy console.

## Builing instructions

Assuming WASM-4 is already installed on your system:

```shell
# Build the game
zig build

# launch the game in the browser
w4 run zig-out/lib/lingword.wasm
```

## Controls

Keyboard:

* Arrow keys moves the cursor
* Ctrl or Space (button 1) selects the current letter/menu option
* Alt (button 2) cancels the previous input

Gamepads should also work.

## Interpreting results / color scheme

The game will color your guesses as follows:

* a letter in a green square means this letter is correctly positioned
* a letter in a yellow square means the answer contains this letter at another position
* a letter in a black square means this letter is not part of the answer
