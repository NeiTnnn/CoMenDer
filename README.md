# CoMenDer — Your Local AI Command-Line Coworker

[English](README.md) | [繁體中文](README.zh-TW.md)

> Enter PowerShell commands directly. When a command fails, get a suggested correction and confirm before running it.

CoMenDer is a demo application that runs in the Windows terminal. It combines PowerShell environment information with a local language model to help correct command names, parameters, and filenames, reducing the need to repeatedly edit commands.

The model runs locally through **Ollama**, using **Qwen2.5-Coder 3B** by default. File candidates are searched and ranked by the program; command and parameter corrections are suggested by the model. Users remain responsible for checking that each correction matches their intent.

## Features

| Feature | Behavior |
|---|---|
| Automatic repair flow | Enter commands directly in CoMenDer mode. Failed commands trigger assistance without a `fix` prefix. |
| Command-name correction | For example, `Get-ChlidItem` → `Get-ChildItem`. |
| Parameter-name correction | The model receives valid parameters and aliases, such as `-TotalCont` → `-TotalCount`. |
| Filename candidate search | Searches only the current directory and shows up to three candidates ranked by filename edit distance. |
| User-controlled file selection | Distinguishes close and weak matches instead of treating a candidate as the correct answer. |
| Confirmation before execution | Shows the original command, suggested command, and reason. Only `y` or `yes` runs the correction. |
| Model calls only when needed | Correct commands run directly; filename searches are handled by the program. |
| Batch validation | Includes a test script and CSV result export. |

## Requirements

- Windows with Windows PowerShell 5.1. The scripts also use syntax intended to be compatible with PowerShell 7, but comprehensive cross-version validation has not been completed.
- [Ollama](https://ollama.com/download/windows) installed and running.
- `qwen2.5-coder:3b`, or another compatible local text model, already downloaded.
- No additional Python, Node.js, or Python packages are required.

Downloading a model for the first time requires internet access. Once downloaded, this demo sends inference requests only to local Ollama. Whether an ordinary command accesses the network depends on the command you enter.

## Quick Start

### 1. Download the local model

After installing Ollama, reopen PowerShell and run:

```powershell
ollama --version
ollama pull qwen2.5-coder:3b
```

Keep Ollama running after the download finishes.

### 2. Extract and launch

Extract the complete `CoMenDer-Demo.zip`, keeping its directory structure. In the `CoMenDer` directory, double-click:

```text
Launch-CoMenDer.cmd
```

The launcher opens Windows PowerShell, displays the model status, and enters the included `demo` directory.

To use your current PowerShell or Conda environment, first navigate to the extracted `CoMenDer` directory, then run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
Get-ChildItem -Filter *.ps1 | Unblock-File
.\Start-CoMenDer.ps1
```

The `Process` execution-policy setting affects only the current PowerShell process. `Unblock-File` removes the downloaded-file origin mark; it does not execute the script or check its safety.

### 3. Enter your first command

At the CoMenDer prompt, enter:

```powershell
Get-ChlidItem
```

This command is intentionally misspelled. The expected flow is shown below; the model's explanation may vary:

```text
Original : Get-ChlidItem
Suggested: Get-ChildItem
Reason   : 指令名稱拼字錯誤。
Run suggested command once? [y/N]:
```

Enter `y` after checking that the suggestion matches your intent. Press Enter without typing anything to cancel. The current model prompt requests explanations in Traditional Chinese.

## Three-Minute Demo

Enter `/demo` and select an example by number. Selecting an example switches back to the included `demo` directory.

| Example | Input | Expected demonstration |
|---|---|---|
| 1. Command typo | `Get-ChlidItem` | The local model suggests `Get-ChildItem`; confirmation lists the files. |
| 2. Filename typo | `Get-Content .\ntoes.txt -TotalCount 2` | Lists `notes.txt` as a close candidate; select the file, then confirm the command. |
| 3. Parameter typo | `Get-Content .\notes.txt -TotalCont 2` | Uses valid parameter information to suggest `-TotalCount`, preserving the value `2`. |
| 4. No clear match | `Get-Content .\unavailable_document_92847.txt -TotalCount 2` | Shows weak candidates without assuming intent; cancel or explicitly select a file. |
| 5. Correct command | `Get-Content .\notes.txt -TotalCount 2` | Outputs the content directly without calling the model. |

A suggested narration sequence is: input error → local context collection → suggestion → user confirmation → one execution attempt.

### File-selection example

```text
找不到指定檔案。以下只是目前資料夾的搜尋候選，請先選擇檔案。
[1] notes.txt (close spelling)
[2] meeting.txt (weak match; may be unrelated)
Select a file number, or Enter to cancel:
```

The first line explains that the requested file was not found and asks you to choose from current-directory candidates. Enter a number, review the complete command, and enter `y` to run it. Even the highest-ranked candidate is not necessarily the file you originally intended to read.

## Commands

| Command | Purpose |
|---|---|
| `/demo` | Select a built-in demonstration. |
| `/status` | Show the local model, Ollama status, current directory, and limits. |
| `/models` | List downloaded models. |
| `/model MODEL_NAME` | Switch the model used in the current session. |
| `/help` | Show help. |
| `/clear` | Clear the terminal screen. |
| `/exit` or `exit` | Exit CoMenDer. |
| `cd "DIRECTORY_PATH"` | Change the current directory. |

Specify a starting directory:

```powershell
.\Start-CoMenDer.ps1 -WorkingDirectory "C:\Users\USER\Downloads"
```

Specify a downloaded model:

```powershell
.\Start-CoMenDer.ps1 -Model "qwen2.5-coder:3b"
```

Download the model through Ollama first. Changing models can affect correction quality, response format, and speed, so rerun the tests.

## How It Works

### Command and parameter errors

1. PowerShell runs the original command and captures its status and output.
2. On failure, the program collects the command, output tail, current directory, some filenames, and relevant command names.
3. For recognized PowerShell commands, it adds actual parameter names, aliases, and types.
4. It calls the local model through `http://127.0.0.1:11434/api/generate`, requesting a correction and reason in JSON.
5. It checks the response format and PowerShell syntax, displays the complete suggestion, and requests confirmation.
6. With approval, it executes the correction once. If it fails again, it stops.

### Missing files

1. Parse a supported file-reading command to obtain its literal path.
2. Enumerate files only in the current directory, using a separate PowerShell process.
3. Compute filename edit distances, sort by distance and name, and keep up to three candidates.
4. Ask the user to select a file. Replace only the path in the original command, preserving the other arguments.
5. Confirm the complete command before execution.

This flow does not ask the model to guess replacement filenames. Candidates are existing files found by the program; the user makes the final choice.

## Search and Waiting Limits

| Item | Setting and behavior |
|---|---|
| Search scope | Files in the current directory; no subdirectory search. |
| Scan limit | Up to 5,000 files. |
| Search process | Waits up to two seconds; startup and cleanup may add a little time. |
| Candidate count | Up to three. |
| Incomplete search | Indicates that candidates come only from scanned files; a hard timeout may produce no candidates. |
| Model HTTP request | 30-second timeout. |
| Correction execution | At most one retry per correction. |

Search reads filenames, not file contents. Timeouts apply to searches and model requests, **not to execution of the original command**.

## Testing

In ordinary PowerShell, navigate to the project directory and run:

```powershell
.\Test-CommandFix.ps1
```

This suite has 10 behavior cases and two search-boundary cases covering:

- Command-name corrections, including commands with paths, and parameter-name corrections.
- Filename candidates, including paths with spaces.
- Explicit candidate selection instead of automatic replacement for missing files.
- Correct commands without model calls.
- Candidates restricted to the current directory, excluding subdirectories.
- The file-scan limit.
- Returning on timeout when the search worker deliberately stalls.

Tests run fixed, read-only cases in a temporary directory and **do not execute model suggestions**. A `CommandFix-results-TIMESTAMP.csv` file is written next to the test script, recording cases, expected and actual results, reasons, errors, and elapsed times.

Repeat the model and behavior cases for three rounds:

```powershell
.\Test-CommandFix.ps1 -Repeat 3
```

This runs 10 × 3 behavior cases plus the two search-boundary cases once, for 32 checks in total.

The user has reported **12/12 passing on Windows** and has manually confirmed candidate selection and execution confirmation. These results apply only to the fixed cases, not to all PowerShell commands. The CoMenDer launcher interface has completed static checks and still requires a Windows runtime trial.

Test elapsed times include command execution and search work. The elapsed time displayed by CoMenDer also includes user confirmation time, so it is not a direct measurement of model inference speed.

## Project Files

| File | Purpose |
|---|---|
| `Launch-CoMenDer.cmd` | Double-click launcher for the Windows PowerShell demo. |
| `Start-CoMenDer.ps1` | Dedicated command loop, model status, demo menu, and shortcuts. |
| `CommandFix.ps1` | Command execution, context collection, model requests, candidate search, and correction confirmation. |
| `Test-CommandFix.ps1` | Batch behavior and search-boundary tests. |
| `demo/notes.txt` | File-reading example for typo and parameter correction. |
| `demo/meeting.txt` | A second file candidate. |
| `README.md` | English setup, demo, testing, and limitations guide. |
| `README.zh-TW.md` | Traditional Chinese setup, demo, testing, and limitations guide. |

## Data Handling

- Model requests go only to local Ollama; no cloud AI API is used.
- The model may receive command text, the output tail, the current directory path, some filenames, and command parameter information.
- The program does not proactively read file contents for the model or collect full command history or environment variables. However, command output itself may contain file contents or other data.
- Tests generate local CSV files. The demo interface does not include additional telemetry or history logging.

## Known Limitations

- This is a dedicated command loop, not an interceptor for other existing PowerShell windows.
- It does not provide full PowerShell completion, history editing, or persistent variable scope. New variables and functions are not guaranteed to persist between commands.
- Output is collected before being displayed, making this version unsuitable for interactive programs, large continuous output, or long-running tasks.
- Filename candidates currently support simple literal paths in `Get-Content`, `cat`, `type`, and `gc`. Dynamic paths, wildcards, multiple files, and compound syntax are not supported by this flow.
- Syntax checks and confirmation prompts are included, but there is no complete command sandbox or dangerous-operation blocker. Model prompt rules do not replace program-level permission controls.
- The original command executes first. Partial success before failure may already have changed files or the environment.
- Slower hardware or a cold model start may exceed the 30-second request timeout.

## FAQ

**Ollama or the model cannot be found**  
Open Ollama and run `ollama --version` and `ollama pull qwen2.5-coder:3b` in another PowerShell window. Enter `/status` in the demo to check again.

**The execution policy blocks the script**  
Use the earlier `Set-ExecutionPolicy -Scope Process Bypass` and `Unblock-File` steps in your project directory. On organization-managed computers, follow the environment's Group Policy settings.

**The test reports that `Get-FixSuggestion` is missing**  
Confirm that `CommandFix.ps1` in the same directory is the updated version, that its name has not become `CommandFix (1).ps1`, and that the old file has been replaced.

**The search times out or finds no candidates**  
A large directory, slow disk, or slow process startup may reach the search limit. Only the current directory is searched; use `cd` to navigate to the correct location, then retry.

**Why does filename correction not show Asking local model?**  
The program searches and ranks filenames, then replaces the path after your selection. No model call is needed for this flow.
