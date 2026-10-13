-- Opens SAP MII Workbench.jsp files via ~/bin/mii-workbench
on open theFiles
	repeat with f in theFiles
		launchWorkbench(POSIX path of f)
	end repeat
end open

on run
	launchWorkbench(POSIX path of (path to home folder) & "Downloads/Workbench.jsp")
end run

on launchWorkbench(p)
	set logFile to POSIX path of (path to home folder) & "Library/Logs/mii-workbench.log"
	do shell script "nohup \"$HOME/bin/mii-workbench\" " & quoted form of p & " > " & quoted form of logFile & " 2>&1 &"
end launchWorkbench
