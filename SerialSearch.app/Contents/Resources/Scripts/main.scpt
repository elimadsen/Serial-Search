global tmpFiles
set tmpFiles to POSIX path of (path to temporary items)

on getSerialsFromFile() -- IDEA get serial numbers from an excel document and write modelListData to the same excel document on writeDataToFile
	set AppleScript's text item delimiters to {":"}
	tell application "Finder" to set containerPath to (container of (path to me))
	set serialList to (POSIX path of (containerPath as alias)) & "List of serial numbers.txt"
	set listOfSerials to {} -- needs to start by setting listOfSerials to blank
	try
		set serialNumbers to paragraphs of (read serialList) -- puts each serial number on its own line
	on error
		set serialNumbers to "Error" -- TODO better error handling. (might not always be erroring because empty)
		display dialog "No data in " & serialList with title "Error" buttons {"Edit", "Quit"} default button "Quit"
		set button_pressed to button returned of result
		log button_pressed
		if button_pressed is "Edit" then -- IDEA create file if it doesn't exist. allow pasting from clipboard?
			do shell script "open " & quoted form of serialList
			delay 1.5
			quit -- IDEA instad of quitting, display dialog that says continue so user doesn't have to open file again
		else if button_pressed is "Quit" then
			quit
		end if
	end try
	repeat with nextLine in serialNumbers -- creates array of serial numbers
		if length of nextLine is greater than 0 then
			copy nextLine to the end of listOfSerials
		end if
	end repeat
	return listOfSerials
end getSerialsFromFile

on getModelInfo(serialList)
	tell application "Mactracker" to «event aevtopmw» -- opens Mactracker in background (needs to be as early as possible to not error when opening with configCode)
	set AppleScript's text item delimiters to {","}
	set modelListData to ""
	set serialCount to length of serialList
	set progress total steps to serialCount
	set progress completed steps to 0
	set progress description to "Processing Serial Numbers..."
	set progress additional description to "Preparing to process."
	set a to 0
	repeat with serialNumber in serialList
		set progress additional description to "Processing Serial " & a & " of " & serialCount
		set AppleScript's text item delimiters to {"><"}
		set endSerial to text -4 through -1 of serialNumber -- tires first to get configCode with last 4 of serial
		tell application "System Events" to do shell script "cd " & tmpFiles & ";curl https://support-sp.apple.com/sp/product?cc=" & endSerial
		set xmlText to result
		if xmlText contains "error" then
			set endSerial to text -3 through -1 of endSerial -- on error tries to get configCode with last 3 of serial
			tell application "System Events" to do shell script "cd " & tmpFiles & ";curl https://support-sp.apple.com/sp/product?cc=" & endSerial
			set xmlText to result
		end if
		set xmlText to every text item of xmlText
		repeat with textItem in xmlText
			if textItem contains "configCode" then -- parses xml text for configCode element
				set AppleScript's text item delimiters to {"<", ">"}
				set xmlData to every text item of textItem -- uses delimiters to separate element
				set AppleScript's text item delimiters to {", "}
				set configCode to text item 2 of xmlData -- grabs just the configCode
			end if
		end repeat
		tell application "Mactracker" to «event aevtopmw» given «class name»:configCode -- opens Mactracker window that matches configCode
		checkMactracker(configCode)
		set MactrackResult to result
		set modelListData to modelListData & serialNumber & ": " & MactrackResult & ": " & configCode & return
		set a to a + 1
		set progress completed steps to a
	end repeat
	closeApp("Mactracker")
	set progress total steps to 0
	set progress completed steps to 0
	set progress description to ""
	set progress additional description to ""
	return modelListData
end getModelInfo

on writeDataToFile(modelListData)
	tell application "Finder" to set containerPath to (container of (path to me))
	set modelList to (POSIX path of (containerPath as alias)) & "Results - " & (current date)
	do shell script "echo  " & quoted form of modelListData & " >  " & quoted form of modelList & ";open " & quoted form of modelList -- TODO write to excel instead of text file
end writeDataToFile

on checkMactracker(configCode)
	tell application "System Events"
		try
			set mactrackerRows to get value of attribute "AXChildren" of table 1 of UI element 1 of scroll area 1 of window configCode of application process "Mactracker"
		on error
			delay 2
			log "Error setting mactrackerRows. Trying again..."
			try
				set mactrackerRows to get value of attribute "AXChildren" of table 1 of UI element 1 of scroll area 1 of window configCode of application process "Mactracker"
			on error
				display alert "Error!" message "unable to get rows of Mactracker window " & quoted form of configCode as warning
			end try
		end try -- TODO find a better way to ensure mactrackerRows gets set that doesn't just deley a set amount of time
		set specsList to {"Order Number"}
		set {baseOrderNumber} to {"UNKNOWN"}
		set tmpData to ""
		set rowNum to 1
		repeat with tmpRow in mactrackerRows
			set uiElemNum to 1
			set tmpText to ""
			repeat 2 times
				try
					set tmpValue to value of static text 1 of UI element uiElemNum of row rowNum of table 1 of UI element 1 of scroll area 1 of window configCode of application process "Mactracker"
					set tmpText to tmpText & ": " & tmpValue
					set uiElemNum to uiElemNum + 1
				on error
					set tmpValue to "ERROR"
					set tmpText to tmpText & ": " & tmpValue
					set uiElemNum to uiElemNum + 1
				end try
			end repeat
			set tmpData to TmpData & tmpText & "/ "
			set rowNum to rowNum + 1
		end repeat
	end tell
	set AppleScript's text item delimiters to {"/ "}
	set tmpDataItems to text items of tmpData
	set AppleScript's text item delimiters to {": "}
	set tmpBaseSpecs to ""
	repeat with tmpSpec in specsList
		repeat with tmpItem in tmpDataItems
			try
				if text item 2 of tmpItem starts with tmpSpec then
					set tmpBaseSpecs to tmpBaseSpecs & (text item 3 of tmpItem)
				end if
			on error
			end try
		end repeat
	end repeat
	set {baseOrderNumber} to {(text items of tmpBaseSpecs)}
	return baseOrderNumber
end checkMactracker

on closeApp(applicationName)
	if application applicationName is running then
		do shell script "pkill -x " & applicationName
	end if
end closeApp

set oldDelims to AppleScript's text item delimiters
getSerialsFromFile()
getModelInfo(result)
writeDataToFile(result)
set AppleScript's text item delimiters to oldDelims
