-- PixProSwapLayers 3.2.0 — exchange the stacking order of the selected layers
--
-- The first selected layer trades places with the last, the second with the
-- second to last. An odd layer in the middle has no partner and stays put.
-- Layers in different groups are handled: `index` counts within a layer's own
-- parent, so each move names that parent, and when the two layers do not share
-- one, the second move goes `before` the old position rather than `after`.
--
-- Fewer than two layers selected: it says so and finishes. It does not wait.
-- A dialog of this app's own takes the focus the moment it appears, so the
-- layers cannot be clicked; a notification instead is silent when
-- notifications are off; and an app left waiting swallows the next launch,
-- because macOS will not start a second copy of it.
--
-- One version number: this property is what the dialogs show, and build.sh
-- reads it for the bundle, so the two cannot disagree.

property scriptVersion : "3.2.0"
property kPixIDs : {"com.apple.pixelmator", "com.pixelmatorteam.pixelmator.x"}
-- Set by pixTarget() before anything talks to Pixelmator.
property pixApp : ""
on pixTarget()
	set rawPaths to {}
	try
		set psOut to do shell script "/bin/ps -Axo args= | /usr/bin/grep '/Contents/MacOS/Pixelmator' | /usr/bin/grep -v grep | /usr/bin/sed 's|/Contents/MacOS/.*||' | /usr/bin/sort -u"
		-- `do shell script` separates lines with RETURN, not linefeed. Split on
		-- the wrong one and every path arrives glued into a single string.
		set AppleScript's text item delimiters to return
		set rawPaths to text items of psOut
		set AppleScript's text item delimiters to ""
	end try
	
	-- Keep only genuine Pixelmator Pro builds, identified by the bundle id in
	-- each app's OWN Info.plist. Nothing here depends on what the app is
	-- called or where it lives, so this works on any Mac: renamed bundles,
	-- App Store or Setapp copies, apps in ~/Applications, all fine. It also
	-- excludes the classic Pixelmator (com.pixelmatorteam.pixelmator), whose
	-- dictionary is different and which would fail halfway through.
	set candidates to {}
	repeat with rp in rawPaths
		set p to rp as text
		if p is not "" then
			try
				set theID to do shell script "/usr/bin/defaults read " & quoted form of (p & "/Contents/Info") & " CFBundleIdentifier"
				if theID is in kPixIDs then set end of candidates to p
			end try
		end if
	end repeat
	if candidates is {} then return ""
	
	-- Which of them, if any, is frontmost. The frontmost process's pid maps
	-- back to its bundle path through ps.
	set frontPath to ""
	try
		-- Bounded: asking System Events which app is frontmost needs Automation
		-- permission, and on an app's FIRST run that call sits there waiting
		-- for a consent prompt. If the prompt does not appear — and it may
		-- not, for a freshly built applet — the script hangs with no window
		-- and nothing to click. Five seconds, then carry on without it: the
		-- frontmost check only orders the candidates, it does not find them.
		with timeout of 5 seconds
			tell application "System Events"
				set fpid to unix id of (first application process whose frontmost is true)
			end tell
		end timeout
		set frontPath to do shell script "/bin/ps -p " & fpid & " -o args= | /usr/bin/sed 's|/Contents/MacOS/.*||'"
	end try
	
	set ordered to {}
	repeat with c in candidates
		set cc to c as text
		if cc is equal to frontPath then set end of ordered to cc
	end repeat
	repeat with c in candidates
		set cc to c as text
		if cc is not equal to frontPath then set end of ordered to cc
	end repeat
	
	repeat with c in ordered
		set cc to c as text
		try
			using terms from application "Pixelmator Pro Creator Studio"
				tell application cc
					if (count of documents) > 0 then return cc
				end tell
			end using terms from
		end try
	end repeat
	return item 1 of ordered
end pixTarget

on dialogTitle()
	return "PixProSwapLayers v" & scriptVersion
end dialogTitle

on bringForward()
	try
		tell me to activate
	end try
end bringForward

on alertUser(msg)
	my bringForward()
	display dialog msg buttons {"OK"} default button "OK" with title my dialogTitle()
end alertUser

on run
	set pixApp to pixTarget()
	if pixApp is "" then
		my alertUser("Pixelmator Pro is not running. Open Pixelmator Pro and a document, select the layers to swap, and try again.")
		return
	end if

	using terms from application "Pixelmator Pro"
		tell application pixApp
			if (count of documents) is 0 then
				my alertUser("No document is open in Pixelmator Pro.")
				return
			end if

			tell front document
				-- Wait rather than refuse. Launching this app takes the focus
				-- off Pixelmator, and a selection made before that is not
				-- always still there when the script reads it — so the dialog
				-- stays up while the layers are selected, and reads the
				-- selection again when Swap is clicked.
				set chosen to selected layers
				set pairCount to (count of chosen)
				-- NO DIALOG while we wait. A dialog put up by this app takes
				-- the focus the moment it appears, however carefully
				-- Pixelmator is activated first, and the layers cannot be
				-- clicked while it is there — the user could only cancel.
				-- Instead Pixelmator is brought forward and the selection is
				-- watched, so the layers can be picked normally and the swap
				-- happens as soon as two of them are.
				-- With fewer than two layers selected it says so and stops.
				--
				-- WAITING WAS TRIED THREE TIMES AND DOES NOT WORK HERE. A
				-- dialog of this app's own takes the focus the moment it
				-- appears, so the layers cannot be clicked; a notification
				-- instead is silent when notifications are switched off, and
				-- the app then sits there invisibly; and an app that sits
				-- there swallows the NEXT launch, because macOS will not start
				-- a second copy — so clicking it again appears to do nothing
				-- at all. Finishing immediately is the only behaviour that is
				-- always visible and always leaves a clean slate.
				if pairCount < 2 then
					my alertUser("Select two or more layers in Pixelmator Pro, then run PixProSwapLayers again." & return & return & "Selected now: " & (pairCount as text))
					return
				end if

				-- Outermost pair inwards: first with last, second with second
				-- to last. An odd layer in the middle has no partner and stays
				-- where it is.
				repeat with idxA from 1 to (pairCount div 2)
					set idxB to pairCount - idxA + 1

					-- Whichever sits LOWER in the stack is treated as A, so
					-- the two moves below always run in the same direction.
					set swapA to item idxA of chosen
					set swapB to item idxB of chosen
					if (index of swapA) > (index of swapB) then
						set swapA to item idxB of chosen
						set swapB to item idxA of chosen
					end if

					set oldA to index of swapA
					set oldB to index of swapB
					set parentA to parent of swapA
					set parentB to parent of swapB

					-- `index` counts within the layer's own parent, so a move
					-- has to name that parent whenever the layer is in a group.
					if parentA is missing value then
						move swapB to after layer oldA
					else
						move swapB to after layer oldA in parentA
					end if

					-- Moving B has already shifted A when the two share a
					-- parent; when they do not, A has to land before the old
					-- position rather than after it.
					set crossesGroups to (parentA is not parentB)
					if parentB is missing value then
						if crossesGroups then
							move swapA to before layer oldB
						else
							move swapA to after layer oldB
						end if
					else
						if crossesGroups then
							move swapA to before layer oldB in parentB
						else
							move swapA to after layer oldB in parentB
						end if
					end if
				end repeat
			end tell
		end tell
	end using terms from
end run
