%include 'inc/func.inc'
%include 'inc/gui.inc'

	fn_function gui/view_transparent
		;inputs
		;r0 = view object
		;trashes
		;r0-r3, r5-r15

		;paste dirty patch
		vp_xor r8, r8
		vp_xor r9, r9
		vp_cpy [r0 + gui_view_w], r10
		vp_cpy [r0 + gui_view_h], r11
		fn_jmp gui/view_add_transparent

	fn_function_end
