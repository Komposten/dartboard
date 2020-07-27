# dartboard

[![Dart CI](https://github.com/Komposten/dartboard/workflows/Dart%20CI/badge.svg)](https://github.com/Komposten/dartboard/actions?query=workflow%3A"Dart+CI") [![codecov](https://codecov.io/gh/Komposten/dartboard/branch/master/graph/badge.svg?token=O0NHEQR9UL)](https://codecov.io/gh/Komposten/dartboard)

**A shell/REPL interface for executing dart code directly from the command line.**

dartboard provides an executable which can be used as an interactive command line shell, similar to how you can run `python` in a terminal to get an interactive Python prompt.

## Installing
1. Install `dartboard` as a global package:
    ```bash
    pub global activate --source git https://github.com/komposten/dartboard.git
    ```
2. Add the [pub cache's bin directory](https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path) to `PATH`.
3. Run `dartboard` in a terminal.

## Using dartboard

#### Limitations

Due to Dart not having an `eval` function, it is not possible to execute each individual line of code in the current isolate. So in order to execute the code provided by the user, dartboard has to create a temporary dart script and execute it in a new isolate. This means that we can't share memory from one execution to the next, and therefore we can't execute each instruction when it is entered.

#### How to use dartboard

Since we can't evaluate each instruction individually, dartboard instead works in blocks which are terminated with special keywords. Pressing 'enter' will not trigger the execution of the code on the same line, but simply move on to a new line, as if writing a script in a text editor.

Code blocks are executed by ending a line with one of two keywords: `end;` or `eval;`

#### `end;`
Executes the preceding code block and then clears it from memory. `end;` should be used when a code block is completed and the data in it is no longer needed. After execution, a new code block will be started and it will not have access to any variables or functions defined in the previous block.

#### `eval;`
Executes the preceding code block without clearing it from memory. `eval;` can be used if you want test the code in the current code block to see if it works, or to check the output. After `eval;` has completed, new code lines will be appended to the code block as if nothing has happened. The `eval;` keyword itself is not included in the code block.

The next time `eval;` or `end;` is used, the entire code block will be run again (including the code from before previous `eval;` runs).

#### dartboard keywords
Here is a list of all available keywords and their effects:
- `end;` - Executes the preceding code block and clears it from dartboard's memory.
- `eval;` - Executes the preceding code block but keeps it in memory.
- `exit;` - Terminates dartboard. Must be written on its own line.
- `undo;` - Removes the last line from the current code block. Must be written on its own line.
- `echo;` - Prints all lines of the current code block. Must be written on its own line.
- `clear;` - Clears the current code block without executing the code.
- `insert:#;<code>` - Inserts `<code>` at line `#`.
- `edit:#;<code>` - Replaces the code at line `#` with `<code>`.
- `delete:#;` - Deletes the code at line `#`.

#### A simple usage example:

```bash
$ dartboard
1  > print('Hello World!');
2  > end;
Hello World!

1  > // A new code block starts here.
2  > print('Let\'s try eval!');
3  > eval;
Let's try eval!

4  > // We're still in the same code block.
5  > print('o_o');
6  > end;
Let's try eval!
o_o
```
