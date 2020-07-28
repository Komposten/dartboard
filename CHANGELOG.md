## 0.1.1
**Additions**
- Allow usage of `await` in Dartboard code.

**Fixes**
- Infinite loop when starting Dashboard after installing it using `pub global activate --source git`.
- Template file cannot be loaded if Dashboard was installed using `pub global activate --source git`.

## 0.1.0

First functional release version.

**Features**
- Execute user-provided code in a terminal based on keywords.
- Keywords: `end`, `eval`, `exit`, `undo`, `echo`, `clear`, `insert`, `edit`, `delete`
- Support for package import statements.
- Handle errors in user-provided code and display correct line numbers.
- Run Dartboard directly from other Dart code, using custom input and output streams to send and receive data.
