;; -*- lisp -*-

;; This file is part of cl-parametric-types.
;; Copyright (c) 2016 Massimiliano Ghilardi
;;
;; This library is free software: you can redistribute it and/or
;; modify it under the terms of the Lisp Lesser General Public License
;; (http://opensource.franz.com/preamble.html), known as the LLGPL.
;;
;; This library is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty
;; of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
;; See the Lisp Lesser General Public License for more details.

#|

aliases for common types

|#

(in-package :cl-parametric-types.lang)

(deftype simple-t-array (&optional (dimensions '*))
  "simple-array of T"
  `(simple-array t ,dimensions))

(deftype simple-array1 (&optional (element-type '*) (size '*))
  "one-dimensional simple-array"
  `(simple-array ,element-type (,size)))

(deftype simple-t-array1 (&optional (size '*))
  "one-dimensional simple-array of T. Equivalent to misnamed CL:SIMPLE-VECTOR"
  `(simple-array t (,size)))

(deftype simple-char-string (&optional (size '*))
  "one-dimensional simple-array of CHARACTER"
  `(svector character ,size))

#-(and)
(deftype simple-base-string (&optional (size '*))
  "one-dimensional simple-array of BASE-CHAR. Equivalent to CL:SIMPLE-BASE-STRING"
  `(svector base-char ,size))
