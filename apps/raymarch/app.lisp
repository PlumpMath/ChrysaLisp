;import canvas class method slots
(defq slot_set_fbox nil slot_fill nil slot_swap nil)
(within-compile-env (lambda ()
	(import 'class/canvas/canvas.inc)
	(setq slot_set_fbox (method-slot 'canvas 'set_fbox)
		slot_fill (method-slot 'canvas 'fill)
		slot_swap (method-slot 'canvas 'swap))))

;math tools
(run 'apps/canvas/math.lisp)

(bind '(canvas canvas_width canvas_height canvas_scale) argv)

(defq
	eps 0.02
	min_distance 0.01
	clipfar 8.0
	arg_march 1.0
	light_pos (list 0.0 0.0 -4.0))

;field equation for a sphere
(defun sphere (p c r)
	(sub (vec-length-3d (vec-sub-3d p c)) r))

;the scene
(defun scene ((x y z))
	(sphere (list (sub (frac x) 0.5) (sub (frac y) 0.5) (sub (frac z) 0.5))
			(list 0.0 0.0 0.0) 0.35))

(defun get-normal ((x y z))
	(vec-norm-3d (list
		(sub (scene (list (add x eps) y z)) (scene (list (sub x eps) y z)))
		(sub (scene (list x (add y eps) z)) (scene (list x (sub y eps) z)))
		(sub (scene (list x y (add z eps))) (scene (list x y (sub z eps)))))))

(defun ray-march (ray_origin ray_dir l max_l)
	(defq i -1 d 1.0)
	(while (and (lt (setq i (inc i)) 1000)
				(gt d min_distance)
				(lt l max_l))
		(defq d (scene (vec-add-3d ray_origin (vec-scale-3d ray_dir l)))
			l (add l (fmul d arg_march))))
	(if (gt d min_distance) max_l l))

(defun lighting (surface_pos surface_norm cam_pos)
	(defq obj_color (vec-floor-3d (vec-mod-3d surface_pos 2.0))
		light_vec (vec-sub-3d light_pos surface_pos)
		light_dis (vec-length-3d light_vec)
		light_norm (vec-scale-3d light_vec (fdiv 1.0 light_dis))
		light_atten (min (fdiv 1.0 (fmul light_dis light_dis 0.01)) 1.0)
		ref (vec-reflect-3d (vec-scale-3d light_norm -1.0) surface_norm)
		ambient 0.05
		diffuse (max 0.0 (vec-dot-3d surface_norm light_norm))
		specular (max 0.0 (vec-dot-3d ref (vec-norm-3d (vec-sub-3d cam_pos surface_pos))))
		specular (fmul specular specular specular specular 0.8)
		obj_color (vec-scale-3d obj_color (add (fmul diffuse 0.8) ambient))
		obj_color (vec-add-3d obj_color (list specular specular specular))
		light_col (vec-scale-3d '(1.0 1.0 1.0) light_atten))
	(vec-mul-3d obj_color light_col))

(defun scene-ray (ray_origin ray_dir)
	(defq l (ray-march ray_origin ray_dir 0.0 clipfar))
	(if (ge l clipfar)
		(list 0.0 0.0 0.0)
		(progn
			(defq surface_pos (vec-add-3d ray_origin (vec-scale-3d ray_dir l))
				surface_norm (get-normal surface_pos)
				color (lighting surface_pos surface_norm ray_origin))
			(vec-clamp color 0.0 0.999))))

(defun screen (w h s)
	(defq y 0 w (div (fmul w s) 1.0) h (div (fmul h s) 1.0) w2 (div w 2) h2 (div h 2))
	(while (lt y h)
		(defq x 0)
		(while (lt x w)
			(defq
				ray_origin (list 0 0 -3.0)
				ray_dir (vec-norm-3d (vec-sub-3d
					(list
						(div (mul (sub x w2) 1.0) w2)
						(div (mul (sub y h2) 1.0) h2)
						0.0) ray_origin)))
			(bind '(r g b) (scene-ray ray_origin ray_dir))
			(call slot_set_fbox canvas
				(add (bit-shr r 8) (bit-and g 0xff00) (bit-shl (bit-and b 0xff00) 8) 0xff000000)
				x y 1 1)
			(while nil) ;while does a yield call !
			(setq x (inc x)))
		(call slot_swap canvas)
		(setq y (inc y))))

(screen canvas_width canvas_height canvas_scale)
