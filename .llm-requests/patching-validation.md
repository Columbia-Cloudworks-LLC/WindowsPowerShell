
# Patching Validation Requirements

Problem:

System Administrators need a quick, easy, repeatable way to validate patching on a list of windows servers that they manage.

The environments in which this script may run vary widely. Some environments, for example, allow WinRM and Invoke-Command, others do not. The script needs to work in the most restrictive environments that the administrators support.

The script needs to validate several things because the administrator just spent many potentially frantic late night hours patching many servers.

 -If the admin forgot to reboot a server after a patch was installed, that needs to be pointed out
 -If no patches were installed in the last 24 hours, the server may have been missed. This needs to be pointed out.
 -If a server is offline, the admin may include an invalid hostname in their list of servers or the server may have been missed or have another issue - this needs to be pointed out.

The output needs to be a timestamped CSV file on the users desktop. The filename should be {AccountName}_{ChangeNumber}_Patches_{Timestamp}.csv

When the user runs the script, the script should detect if it is being run as administrator. If not, it should re-run istself in an elevated context.

When the user runs the script, they should be presented with a simple Graphical User Interface (GUI)
The GUI should include labels for all components. It should close once the user click OK and the script's output should continue in the PowerShell console.

## Collecting User Information

The following information should be collected from the user. Use single-line text boxes where appropriate and multi-line text boxes where appripriate. For multi-line text boxes, we want to allow users to scroll and to be able to copy & paste a multi-line list of hostnames directly into the multiline text box. We need to collect:

- Customer Name
- Change Number
- Servers

## Processing Each Server

While running, the script should get the following information from each server without using WinRM or Invoke-Command.

- IPv4 Address
- Fully-Qualified Domain Name
- Operating System Version
- Last Reboot Time

Combine the values collected from the remote server and provided by the user from the GUI and add it to the output file.

The output should contain the following columns for each patch installed on each remote windows server:

- Customer Name
- Change Number
- Hostname
- IPv4 Address
- Fully-Qualified Domain Name
- Operating System
- KB Number
- Installed On
- Last Reboot

If there were any errors collecting the data from any of the remote windows servers, the error should be appended to an log file in the same directory as the script. The script should know if an error occurred during this specific execution run and, if so, after appending all errors to the log file, open that log file in Notepad after the script completes execution.

## Script Requirements

- PowerShell v5.2 or greater
- No internet connectivity required for execution
- Administrative permission required
- Use Write-Progress while scanning remote servers to indicate progression to the user
- Use functions where appropriate. Maximize reusability for functions when possible.
