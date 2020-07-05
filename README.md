# dart_repl

**A REPL interface for executing dart code directly from the command line.**

dart_repl provides an executable which can be used as an interactive command line shell, similar to how you can run `python` in a terminal to get an interactive python prompt.

## Installing
1. Install `dart_repl` as a global package:
    ```bash
    pub global activate --source git https://github.com/komposten/dart_repl.git
    ```
2. Add the [pub cache's bin directory](https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path) to `PATH`.
3. Run `dart_repl` in a terminal.

## Using dart_repl

#### Limitations

Due to Dart not having an `eval` function, it is not possible to execute each individual line of code in the current isolate. So in order to execute the code provided by the user, dart_repl has to create a temporary dart script and execute it in a new isolate. This means that we can't share memory from one execution to the next, and therefore we can't execute each instruction when it is entered.

#### How to use dart_repl

Since we can't evaluate each instruction individually, dart_repl instead works in blocks which are terminated with special keywords. Pressing 'enter' will not trigger the execution of the code on the same line, but simply move on to a new line, as if writing a script in a text editor.

Code blocks are executed by ending a line with one of two keywords: `end;` or `eval;`

#### `end;`
Executes the preceding code block and then clears it from memory. `end;` should be used when a code block is completed and the data in it is no longer needed. After execution, a new code block will be started and it will not have access to any variables or functions defined in the previous block.

#### `eval;`
Executes the preceding code block without clearing it from memory. `eval;` can be used if you want test the code in the current code block to see if it works, or to check the output. After `eval;` has completed, new code lines will be appended to the code block as if nothing has happened. The `eval;` keyword itself is not included in the code block.

The next time `eval;` or `end;` is used, the entire code block will be run again (including the code from before previous `eval;` runs).

#### dart_repl keywords
Here is a list of all available keywords and their effects:
- `end;` - Executes the preceding code block and clears it from dart_repl's memory.
- `eval;` - Executes the preceding code block but keeps it in memory.
- `exit;` - Terminates dart_repl. Must be written on its own line.
- `undo;` - Removes the last line from the current code block. Must be written on its own line.
- `echo;` - Prints all lines of the current code block. Must be written on its own line.

#### A simple usage example:

```bash
$ dart_repl
>> print('Hello World!');
>> end;
Hello World!

>> // A new code block starts here.
>> print('Let\'s try eval!');
>> eval;
Let's try eval!

>> // We're still in the same code block.
>> print('o_o');
>> end;
Let's try eval!
o_o
```
