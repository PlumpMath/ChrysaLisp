%include 'inc/func.inc'
%include 'class/class_stream.inc'

	fn_function class/stream/write
		;inputs
		;r0 = stream object
		;r1 = buffer
		;r2 = buffer length
		;outputs
		;r0 = stream object
		;trashes
		;all but r0, r4

		ptr inst
		pubyte buffer, buffer_end
		long char

		;save inputs
		push_scope
		retire {r0, r1, r2}, {inst, buffer, buffer_end}

		assign {buffer + buffer_end}, {buffer_end}
		loop_while {buffer != buffer_end}
			assign {*buffer}, {char}
			assign {buffer + 1}, {buffer}
			static_call stream, write_char, {inst, char}
		loop_end

		eval {inst}, {r0}
		pop_scope
		return

	fn_function_end