%include 'inc/func.inc'
%include 'inc/gui.inc'

	fn_function gui/region_free
		;inputs
		;r0 = region heap pointer
		;r1 = source region listhead pointer
		;trashes
		;r1-r3

		;run through source region list
		loop_flist_forward r1, r1, r2
			vp_cpy r1, r3
			ln_remove_fnode r1, r2
			hp_freecell r0, r3, r2
		loop_end
		vp_ret

	fn_function_end
