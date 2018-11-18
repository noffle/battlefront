;;;; battlefront.lisp

(in-package #:battlefront)

;; GOAL: add components + systems s.t. player can be controlled with keyboard

;; [x] basic ecs.lisp integration
;; [x] load in skirmish online player sprite
;; [x] WASD movement controls
;; [ ] mouse-look rotation
;; [ ] camera entity + component that follows player

(require :sdl2)
(require :cl-opengl)

(defstruct pos
  (x 0)
  (y 0)
  (z 0))

(defstruct physics
  (xvel 0)
  (yvel 0)
  (zvel 0))

(defstruct plr-controller)

(defparameter *world* (ecs:make-world))

(defparameter *player* (ecs:create-entity *world*
                                          :components (list (make-pos)
                                                            (make-physics)
                                                            (make-plr-controller))))
(setf (pos-x (ecs:getcmp :pos *player*)) 320)
(setf (pos-y (ecs:getcmp :pos *player*)) 240)

(defparameter *camera-x* 0)
(defparameter *rot* 0)
(defparameter *camera-x* 0)
(defparameter *camera-y* 0)
(defparameter *sprite-tex* nil)
(defparameter *tileset-tex* nil)
(defparameter *tilemap* (make-array (list 20 20)))
;; fun init:
;;(dotimes (n 400) (setf (row-major-aref *tilemap* n) (random 10)))

(ecs:defsystem 2d-physics *world* (e :pos :physics)
               (let ((pos (ecs:getcmp :pos e))
                     (vel (ecs:getcmp :physics e))
                     (gnd-friction 0.93))
                 ;; move pos by velocity
                 (incf (pos-x pos) (physics-xvel vel))
                 (incf (pos-y pos) (physics-yvel vel))
                 ;; apply ground friction
                 (setf (physics-xvel vel) (* gnd-friction (physics-xvel vel)))
                 (setf (physics-yvel vel) (* gnd-friction (physics-yvel vel)))))

(ecs:defsystem player-controller *world* (e :pos :physics :plr-controller)
               (let* ((vel (ecs:getcmp :physics e))
                      (speed 0.15)
                      (xoffset (* speed (+
                                (if (engine:key-down :d) 1 0)
                                (if (engine:key-down :a) -1 0))))
                      (yoffset (* speed (+
                                (if (engine:key-down :w) -1 0)
                                (if (engine:key-down :s) 1 0)))))
                 (incf (physics-xvel vel) xoffset)
                 (incf (physics-yvel vel) yoffset)))

(defun main ()
  (engine:init :title "Battlefront"
               :w 640 :h 480
               :init 'init
               :update 'update
               :render 'render))

(defun init (win gl-context)
  "Setup OpenGL with the window WIN and the gl context GL-CONTEXT"
  (sdl2:gl-make-current win gl-context)
  (gl:enable :texture-2d)
  (gl:enable :blend)
  (gl:blend-func :src-alpha :one-minus-src-alpha)
  (gl:viewport 0 0 640 480)
  (gl:matrix-mode :projection)
  (gl:ortho 0 640 480 0 -2 2)
  (gl:matrix-mode :modelview)
  (gl:load-identity)
  (gl:clear-color 0.0 0.0 0.0 1.0)
  (setq *sprite-tex* (tex-png:make-texture-from-png "player.png"))
  (setq *tileset-tex* (tex-png:make-texture-from-png "tileset.png")))

(defun update ()
  (incf *rot* 0.2)
  (ecs:world-tick *world*))

(defun render ()
  (gl:clear :color-buffer)
  (gl:load-identity)
  (draw-tilemap *tileset-tex* *tilemap* *camera-x* *camera-y*)
  (draw-sprite :texture *sprite-tex*
               :rgba '(1 1 1 1)
               :x (pos-x (ecs:getcmp :pos *player*))
               :y (pos-y (ecs:getcmp :pos *player*))
               :width 64 :height 64
               :rot 0
               :center-x 0.5 :center-y 0.5)
  (gl:flush))

(defun draw-sprite (&key texture
                      (width 32.0) (height 32.0)
                      (x 0.0) (y 0.0)
                      (center-x 0.5) (center-y 0.5)
                      (rot 0.0)
                      (rgba '(1.0 1.0 1.0 1.0))
                      (scale-x 1.0) (scale-y 1.0))
  "Draw a 2D sprite to the screen."
  (let* ((w (* width scale-x))
         (h (* height scale-y))
         (bx (- (* w center-x) w))
         (fx (+ w bx))
         (by (- (* h center-y) h))
         (fy (+ h by)))
    (gl:bind-texture :texture-2d texture)
    (gl:push-matrix)
    (gl:translate x y 0)
    (gl:rotate rot 0 0 1)
    (gl:color (nth 0 rgba) (nth 1 rgba) (nth 2 rgba) (nth 3 rgba))
    (gl:begin :quads)
    (gl:tex-coord 0 0)
    (gl:vertex bx by)
    (gl:tex-coord 0 1)
    (gl:vertex bx fy)
    (gl:tex-coord 1 1)
    (gl:vertex fx fy)
    (gl:tex-coord 1 0)
    (gl:vertex fx by)
    (gl:end)
    (gl:pop-matrix)))

(defun draw-tilemap (texture tilemap x y)
  (let* ((tw (/ 32.0 512.0))
         (th (/ 32.0 32.0))
         (pox (mod x 32))
         (poy (mod y 32)))
    (gl:bind-texture :texture-2d texture)
    (gl:push-matrix)
    (gl:color 1.0 1.0 1.0 1.0)
    (gl:begin :quads)
    (dotimes (i 21)
      (dotimes (j 16)
        (let* ((tile-x (+ i (floor (/ x 32))))
               (tile-y (+ j (floor (/ y 32))))
               (tile-id (aref-2d tilemap tile-x tile-y 10))
               (u (* tile-id tw))
               (v 0)
               (px (- (* i 32) pox))
               (py (- (* j 32) poy)))
          (gl:tex-coord u v)
          (gl:vertex px py)
          (gl:tex-coord u (+ th v))
          (gl:vertex px (+ 32 py))
          (gl:tex-coord (+ tw u) (+ th v))
          (gl:vertex (+ 32 px) (+ 32 py))
          (gl:tex-coord (+ tw u) v)
          (gl:vertex (+ 32 px) py))))
    (gl:end)
    (gl:pop-matrix)))

(defun aref-2d (array x y default)
  "Like aref, but for 2D arrays, and returns DEFAULT if AT is out of bounds."
  (if (or (< x 0)
          (< y 0)
          (>= x (array-dimension array 0))
          (>= y (array-dimension array 1)))
      default
      (aref array x y)))
