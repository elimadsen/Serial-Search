global tmpFiles
set tmpFiles to POSIX path of (path to temporary items)

on getSerialsFromFile()
	set AppleScript's text item delimiters to {":"}
	tell application "Finder" to set containerPath to (container of (path to me))
	set serialList to (POSIX path of (containerPath as alias)) & "List of serial numbers.txt"
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

on getYears(serialList)
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
		set modelListData to modelListData & serialNumber & ": " & configCode & return
		set a to a + 1
		set progress completed steps to a
	end repeat
	set progress total steps to 0
	set progress completed steps to 0
	set progress description to ""
	set progress additional description to ""
	return modelListData
end getYears

on writeDataToFile(modelListData)
	tell application "Finder" to set containerPath to (container of (path to me))
	set modelList to (POSIX path of (containerPath as alias)) & "Results - " & (current date)
	do shell script "echo  " & quoted form of modelListData & " >  " & quoted form of modelList & ";open " & quoted form of modelList
end writeDataToFile

on checkMactracker(configCode)
	tell application "Mactracker"
		«event aevtopmw» given «class name»:configCode
	end tell
	log configCode
	--tell application "System Events"
		--get name of window testtwo of application process "Mactracker"
		--set test to result
		--log test
	--end tell=
	-- TODO close window after collecting information
end checkMactracker

set oldDelims to AppleScript's text item delimiters
getSerialsFromFile()
getYears(result)
writeDataToFile(result)
set AppleScript's text item delimiters to oldDelims
