tell application "Pixelmator Pro"
	tell the front document
		set opt_debug to true
		set op_lays to selected layers
		set numOfSelLays to number of op_lays
		if (numOfSelLays < 2) then
			display dialog "⚠️ - nothing to do. Select at least 2 layers to swap"
			return false
		end if
		# Read position of selected layers before we swap
		
		repeat with idx_a from 1 to ((count of op_lays) / 2)
			set idx_b to (count of op_lays) - idx_a + 1
			# Repair Case #1: Swap A & B to get lowest item in layer stack
			set swap_a to item idx_a in op_lays
			set swap_b to item idx_b in op_lays
			if (index of swap_a > index of swap_b) then
				if opt_debug then display dialog "Case 1 repair: order swap"
				set swap_a to item idx_b in op_lays
				set swap_b to item idx_a in op_lays
			end if
			set old_a to index of swap_a
			set old_b to index of swap_b
			set parent_a to parent of swap_a
			set parent_b to parent of swap_b
			
			if opt_debug then display dialog "1st Swap[" & old_b & "]=" & name of swap_b & " with [" & old_a & "]= " & name of swap_a
			if (parent_a = missing value) then
				move swap_b to after layer (old_a)
			else
				move swap_b to after layer (old_a) in parent_a
			end if
			
			# case #2 - swap_b was moved above swap_a in the same group
			set need_repair to false
			if (parent_a ≠ parent_b) then
				if opt_debug then display dialog "Case 2 repair: group"
				set need_repair to true
			end if
			if (parent_b = missing value) then
				if need_repair then
					move swap_a to before layer (old_b)
				else
					move swap_a to after layer (old_b)
					
				end if
			else
				if need_repair then
					move swap_a to before layer (old_b) in parent_b
				else
					move swap_a to after layer (old_b) in parent_b
				end if
			end if
			
		end repeat
		deselect
	end tell
end tell
