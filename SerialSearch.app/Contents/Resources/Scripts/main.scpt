global tmpFiles
set tmpFiles to POSIX path of (path to temporary items)

on getSerialsFromFile()
	set AppleScript's text item delimiters to {":"}
	tell application "Finder" to set containerPath to (container of (path to me))
	set serialList to "/Users/elimadsen/github/Serial-Search/List of serial numbers.txt" --(POSIX path of (containerPath as alias)) & "List of serial numbers.txt" -- TEMP change this back
	set listOfSerials to {}
	try
		set serialNumbers to paragraphs of (read serialList)
	on error
		set serialNumbers to "Error"
		display dialog "No data in " & serialList with title "Error" buttons {"Edit", "Quit"} default button "Quit"
		set button_pressed to button returned of result
		log button_pressed
		if button_pressed is "Edit" then
			do shell script "open " & quoted form of serialList
			delay 1.5
			quit
		else if button_pressed is "Quit" then
			quit
		end if
	end try
	repeat with nextLine in serialNumbers
		if length of nextLine is greater than 0 then
			copy nextLine to the end of listOfSerials
		end if
	end repeat
	return listOfSerials
end getSerialsFromFile

on getModelInfo(serialList)
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
		set tmpFiles to POSIX path of (path to temporary items)
		set endSerial to text -4 through -1 of serialNumber
		tell application "System Events" to do shell script "cd " & tmpFiles & ";curl https://support-sp.apple.com/sp/product?cc=" & endSerial
		set xmlText to result
		if xmlText contains "error" then
			set endSerial to text -3 through -1 of endSerial
			tell application "System Events" to do shell script "cd " & tmpFiles & ";curl https://support-sp.apple.com/sp/product?cc=" & endSerial
			set xmlText to result
		end if
		set xmlText to every text item of xmlText
		repeat with textItem in xmlText
			if textItem contains "configCode" then
				set AppleScript's text item delimiters to {"<", ">"}
				set xmlData to every text item of textItem
				set AppleScript's text item delimiters to {", "}
				set configCode to text item 2 of xmlData
			end if
		end repeat
		checkMactracker(configCode)
		set modNum to result
		set modelListData to modelListData & serialNumber & ": " & configCode & ": " & modNum & return
		set a to a + 1
		set progress completed steps to a
	end repeat
	closeApp("Mactracker")
	set progress total steps to 0
	set progress completed steps to 0
	set progress description to ""
	set progress additional description to ""
	log modelListData
	return modelListData
end getModelInfo

on writeDataToFile(modelListData)
	tell application "Finder" to set containerPath to (container of (path to me))
	set modelList to (POSIX path of (containerPath as alias)) & "Results - " & (current date)
	-- do shell script "echo  " & quoted form of modelListData & " >  " & quoted form of modelList & ";open " & quoted form of modelList -- TEMP uncomment this
end writeDataToFile

on checkMactracker(configCode)
	tell application "Mactracker"
		«event aevtopmw» given «class name»:configCode
	end tell
	set configCode to ((configCode as text)as string)
	log configCode
	tell application "System Events"
		--get name of table 1 of UI element 1 of scroll area 1 of window 1 of application process "Mactracker"
		--get name of window configCode of application process "Mactracker"
		get name of window "MacBook Pro (Retina, 15-inch, Late 2013)" of application process "Mactracker"
		set test to result
		log test
		--TODO close window after done
	end tell
end checkMactracker

on closeApp(applicationName)
	set applicationName to quoted form of applicationName
	if application applicationName is running then
		close application applicationName
	end if
end closeApp

set oldDelims to AppleScript's text item delimiters
getSerialsFromFile()
getModelInfo(result)
writeDataToFile(result)
set AppleScript's text item delimiters to oldDelims
