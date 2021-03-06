;;;;;;;;;;;;;;
; VP Assembler
;;;;;;;;;;;;;;

(defq debug_mode t debug_emit nil debug_inst nil)

(defun compile (*files* &optional *os* *cpu* *pipes*)
	(setd *os* (platform) *cpu* (cpu) *pipes* 16)
	(defq q (list) e (list))
	(unless (lst? *files*)
		(setq *files* (list *files*)))
	(setq *files* (shuffle (map sym *files*)))
	(while (gt *pipes* 0)
		(defq i (div (length *files*) *pipes*) s (slice 0 i *files*) *files* (slice i -1 *files*))
		(when (ne i 0)
			(push q (defq p (pipe "lisp cmd/lisp.lisp")))
			(pipe-write p (cat "(compile-pipe '" (str s) " '" *os* " '" *cpu* ") ")))
		(setq *pipes* (dec *pipes*)))
	(when (ne 0 (length q))
		(print "Compiling with " (length q) " instances")
		(each (lambda (p)
			(each-pipe-line (lambda (l)
				(defq k (elem 0 (split l " ")))
				(cond
					((eql k "Done"))
					((eql k "Error:") (push e l) nil)
					(t (print l)))) p)) q)
		(each print e))
	(print "Done") nil)

(defun compile-pipe (*files* *os* *cpu*)
	(within-compile-env (lambda ()
		(each import *files*)
		(print "Done"))))

;;;;;;;;;;;;;
; make system
;;;;;;;;;;;;;

(defun make-info (_)
	;create lists of immediate dependencies and products
	(defq d (list 'cmd/lisp.lisp 'class/lisp/boot.lisp _) p (list))
	(each-line _ (lambda (_)
		(when (and (ge (length _) 10) (eql "(" (elem 0 _))
				(le 2 (length (defq s (split _ " "))) 3))
			(defq _ (elem 0 s) o (trim-start (trim-end (elem 1 s) ")") "'"))
			(cond
				((eql _ "(import")
					(push d (sym o)))
				((eql _ "(def-func")
					(push p (sym o)))
				((eql _ "(gen-class")
					(push p (sym-cat "class/class_" o)))
				((eql _ "(gen-new")
					(push p (sym-cat "class/" o "/new")))
				((eql _ "(gen-create")
					(push p (sym-cat "class/" o "/create")))))))
	(list d p))

(defun make (&optional *os* *cpu*)
	(setd *os* (platform) *cpu* (cpu))
	(compile ((lambda ()
		(defq *env* (env 101) *imports* (list 'make.inc))
		(defun func-obj (_)
			(cat "obj/" *os* "/" *cpu* "/" _))
		(defun make-sym (_)
			(sym-cat "_dep_" _))
		(defun make-time (_)
			;modification time of a file, cached
			(defq s (sym-cat "_age_" _))
			(or (def? s) (def *env* s (age _))))
		;list of all file imports while defining dependencies and products
		(each-mergeable (lambda (_)
			(defq i (make-info _))
			(bind '(d p) i)
			(merge-sym *imports* d)
			(elem-set 1 i (map func-obj p))
			(def *env* (make-sym _) i)) *imports*)
		;filter to only the .vp files
		(setq *imports* (filter (lambda (_)
			(and (ge (length _) 3) (eql ".vp" (slice -4 -1 _)))) *imports*))
		;filter to only the files who's oldest product is older than any dependency
		(setq *imports* (filter (lambda (_)
			(defq d (eval (make-sym _)) p (reduce min (map make-time (elem 1 d))) d (elem 0 d))
			(each-mergeable (lambda (_)
				(merge-sym d (elem 0 (eval (make-sym _))))) d)
			(some (lambda (_) (ge _ p)) (map make-time d))) *imports*))
		;drop the make environment and return the list to compile
		(setq *env* nil)
		*imports*)) *os* *cpu*))

(defun make-boot (&optional r *funcs* *os* *cpu*)
	(within-compile-env (lambda ()
		(setd *funcs* (list) *os* (platform) *cpu* (cpu))
		(defq *env* (env 101) z (cat (char 0 8) (char 0 4)))
		(import 'sys/func.inc)
		(defun func-obj (_)
			(cat "obj/" *os* "/" *cpu* "/" _))
		(defun load-func (_)
			(or (def? _)
				(progn
					(defq b (load (func-obj _))
						h (slice fn_header_entry (defq l (read-short fn_header_atoms b)) b)
						l (slice l (defq p (read-short fn_header_strs b)) b))
					(def *env* _ (list (cat (char -1 8) (char p 2) h) l (read-strings b))))))
		(defun read-byte (o f)
			(code (elem o f)))
		(defun read-short (o f)
			(add (read-byte o f) (bit-shl (read-byte (inc o) f) 8)))
		(defun read-int (o f)
			(add (read-short o f) (bit-shl (read-short (add o 2) f) 16)))
		(defun read-long (o f)
			(add (read-int o f) (bit-shl (read-int (add o 4) f) 32)))
		(defun read-cstr (o f)
			(defq k o)
			(while (ne 0 (read-byte o f))
				(setq o (inc o)))
			(sym (slice k o f)))
		(defun read-strings (_)
			(defq l (list) i (read-short fn_header_atoms _) e (read-short fn_header_strs _))
			(while (ne i e)
				(push l (read-cstr (add (read-long i _) i) _))
				(setq i (add i 8))) l)
		(unless (lst? *funcs*)
			(setq *funcs* (list *funcs*)))
		(defq f (list
			;must be first function !
			'sys/load_init
			;must be second function !
			'sys/load_bind
			;must be third function !
			'sys/load_statics
			;must be included, as bind uses them !
			'sys/string_copy
			'sys/string_length
			'sys/pii/exit
			'sys/pii/mmap
			'sys/pii/stat
			'sys/pii/open
			'sys/pii/close
			'sys/pii/read
			'sys/pii/write
			'sys/pii/write_str
			'sys/pii/write_char))
		(merge-sym f (map sym *funcs*))
		;load up all functions requested
		(each load-func f)
		;if recursive then load up all dependents
		(when r
			(each-mergeable (lambda (_)
				(merge-sym f (elem 2 (load-func _)))) f))
		;sort into order
		(sort cmp f 3)
		;list of all function bodies and links in order, list of offsets of header and link sections
		;and offset of new strings section
		(defq b (map eval f) ns (list) nso (list) ho (list) lo (list) so (add (length z) (reduce (lambda (x y)
			(push ho x)
			(push lo (setq x (add x (length (elem 0 y)))))
			(add x (length (elem 1 y)))) b 0)))
		;list of all strings that will appear in new strings section, and list of all new string offsets
		(each (lambda (_)
			(each (lambda (_)
				(unless (find _ f) (insert-sym ns _))) (elem 2 (eval _)))) f)
		(reduce (lambda (x y)
			(push nso x)
			(add x (length y) 1)) ns 0)
		;create new link sections with offsets to header strings or new strings
		(each (lambda (x)
			(defq u (elem _ lo))
			(elem-set 1 x (apply cat (push (map (lambda (y)
				(char (sub (if (defq i (find y f))
					(add (elem i ho) fn_header_pathname)
					(add (elem (find y ns) nso) so)) (add u (mul _ 8))) 8)) (elem 2 x)) "")))) b)
		;build list of all sections of boot image
		;concatenate all sections and save
		(save (setq f (apply cat (reduce (lambda (x y)
			(push x (cat y (char 0)))) ns (push (reduce (lambda (x y)
				(push x (elem 0 y) (elem 1 y))) b (list)) z)))) (func-obj 'sys/boot_image))
		(setq *env* nil)
		(print "image -> " (func-obj 'sys/boot_image) " (" (length f) ")") nil)))

(defun make-boot-all (&optional *os* *cpu*)
	(setd *os* (platform) *cpu* (cpu))
	(make-boot nil ((lambda ()
		(defq *imports* (list 'make.inc) *products* (list))
		;lists of all file imports and products
		(each-mergeable (lambda (_)
			(bind '(d p) (make-info _))
			(merge-sym *imports* d)
			(merge-sym *products* p)) *imports*)
		*products*)) *os* *cpu*))

(defun remake (&optional *os* *cpu*)
	(setd *os* (platform) *cpu* (cpu))
	(make *os* *cpu*)
	(make-boot-all *os* *cpu*))

(defun all-vp-files ()
	(defq *imports* (list 'make.inc))
	;list of all file imports
	(each-mergeable (lambda (_)
		(merge-sym *imports* (elem 0 (make-info _)))) *imports*)
	;filter to only the .vp files
	(filter (lambda (_)
		(and (ge (length _) 3) (eql ".vp" (slice -4 -1 _)))) *imports*))

(defun make-all (&optional *os* *cpu*)
	(setd *os* (platform) *cpu* (cpu))
	(compile (all-vp-files) *os* *cpu*)
	(make-boot-all *os* *cpu*))

;;;;;;;;;;;;;;;;;;;;;
; cross platform make
;;;;;;;;;;;;;;;;;;;;;

(defun make-platforms ()
	(make 'Darwin 'x86_64)
	(make 'Linux 'x86_64)
	(make 'Linux 'aarch64))

(defun remake-platforms ()
	(remake 'Darwin 'x86_64)
	(remake 'Linux 'x86_64)
	(remake 'Linux 'aarch64))

(defun make-all-platforms ()
	(make-all 'Darwin 'x86_64)
	(make-all 'Linux 'x86_64)
	(make-all 'Linux 'aarch64))

;;;;;;;;;;;;;;;;;;;;;;;;
; compile and make tests
;;;;;;;;;;;;;;;;;;;;;;;;

(defun make-test (&optional i &optional *os* *cpu*)
	(setd *os* (platform) *cpu* (cpu))
	(defun time-in-seconds (_)
		(defq f (str (mod _ 1000000)))
		(cat (str (div _ 1000000)) "." (slice 0 (sub 6 (length f)) "00000") f))
	(defq b 1000000000 a 0 c 0)
	(times (opt i 10)
		(defq _ (time))
		(compile (all-vp-files) *os* *cpu*)
		(setq _ (sub (time) _) a (add a _) c (inc c))
		(print "Time " (time-in-seconds _) " seconds")
		(print "Mean time " (time-in-seconds (div a c)) " seconds")
		(print "Best time " (time-in-seconds (setq b (min b _))) " seconds"))
	nil)

(defun compile-test (&optional *os* *cpu*)
	(setd *os* (platform) *cpu* (cpu))
	(each (lambda (_)
		(compile _ *os* *cpu*)) (all-vp-files)))
