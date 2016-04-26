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
Functions to simplify types, i.e. to replace:
  SIGNED-BYTE       -> INTEGER
  UNSIGNED-BYTE     -> (INTEGER 0)
  (SIGNED-BYTE N)   -> (INTEGER (LOGNOT (ASH 1 (1- N))) (ASH 1 (1- N)))
                    -> or FIXNUM if N is the right one
  (SIGNED-BYTE *)   -> INTEGER
  (UNSIGNED-BYTE N) -> (INTEGER 0 (ASH 1 N))
  (UNSIGNED-BYTE *) -> (INTEGER 0)
  (INTEGER N *)     -> (INTEGER N)
  (INTEGER * *)     -> INTEGER
  (INTEGER N M)     -> depending on N and M, one of
                       or FIXNUM or (SIGNED-BYTE X) or (UNSIGNED-BYTE X) or (INTEGER N M)
  (float-type N *)  -> (float-type N)
  (float-type * *)  -> float-type
  (array-type T *)  -> (array-type T)
  (array-type * *)  -> array-type
  (string-type *)   -> string-type
  (MEMBER T NIL)    -> BOOLEAN
  (MEMBER NIL T)    -> BOOLEAN
|#

(in-package #:cl-parametric-types)

(defconstant +most-positive-fixnum-is-power-of-2-minus-1+
  (let ((n most-positive-fixnum))
    (zerop (logand n (1+ n)))))

(defconstant +fixnum-is-twos-complement+
  (eql (lognot most-negative-fixnum) most-positive-fixnum))

(declaim (inline is-power-of-2-minus-1?))
(defun is-power-of-2-minus-1? (n)
  (declare (type integer n))
  (if (typep n 'fixnum)
      (if (< n most-positive-fixnum)
          (zerop (logand n (the fixnum (1+ n))))
          +most-positive-fixnum-is-power-of-2-minus-1+)
      ;; slow bignum arithmetic
      (zerop (logand n (1+ n)))))

(declaim (ftype (function ((or symbol cons)) (values (or symbol cons) &optional)) simplify-type))

(defun simplify-type-unsigned-byte (type)
  (declare (type cons type))
  (let ((bits (or (second type) '*)))
    (case bits
      ;; (unsigned-byte *) -> (integer 0), because the latter is shorter
      ((*) '(integer 0))
      ;; (unsigned-byte 1) -> bit
      (1   'bit)        
      (otherwise  type))))

(defun simplify-type-signed-byte (type)
  (declare (type cons type))
  (let ((bits (or (second type) '*)))
    (cond
      ;; (signed-byte *) -> integer, because the latter is shorter
      ((eq '* bits) 'integer)
      ((and +most-positive-fixnum-is-power-of-2-minus-1+
            +fixnum-is-twos-complement+
            (eql bits #.(1+ (integer-length most-positive-fixnum))))
       ;; (signed-byte #.the-right-number-of-bits) -> fixnum
       #||#   'fixnum)    
      (t      type))))

(defun simplify-type-real (type)
  (declare (type cons type))
  (let ((first (first type))
        (lo (or (second type) '*))
        (hi (or (third  type) '*)))
    (block nil
      (when (eq '* hi)
        (return
          (if (eq '* lo)
              first              ;; (xyz * *) -> xyz
              (list first lo)))) ;; (xyz n *) -> (xyz n)
      
      (when (and (integerp hi) (integerp lo)
                 (is-power-of-2-minus-1? hi))
        (when (eql 0 lo)
          (return (simplify-type-unsigned-byte (list 'unsigned-byte (integer-length hi)))))
        (when (eql (lognot lo) hi)
          (return (simplify-type-signed-byte (list 'signed-byte (1+ (integer-length hi)))))))
      type)))

(defun simplify-type-member (type)
  (declare (type cons type))
  (if (or (equal type '(member t nil))
          (equal type '(member nil t)))
      'boolean
      type))

(defun simplify-type-array (type)
  (declare (type cons type))
  (let ((array-type   (first type))
        (element-type (or (simplify-type (second type)) '*))
        (dimensions   (or (third  type) '*)))
    (block nil
      (when (eq '* dimensions)
        (return
          (if (eq '* element-type)
              array-type      ;; (xyz * *) -> xyz
              (list array-type element-type)))) ;; (xyz el-type *) -> (xyz el-type)
      (list array-type element-type dimensions))))

(defun simplify-type-string (type)
  (declare (type cons type))
  (let ((dimensions (or (second type) '*)))
    (if (eq '* dimensions)
        (first type) ;; (xyz *) -> xyz
        type)))

(defun simplify-type (type)
  (declare (type (or symbol cons) type))
  (etypecase type
    (symbol
     (case type
       ;; signed-byte -> integer, for uniformity
       ;; with (signed-byte *) -> integer above
       (signed-byte   'integer)
       ;; unsigned-byte -> (integer 0), for uniformity
       ;; with (unsigned-byte *) -> (integer 0) above
       (unsigned-byte '(integer 0))
       (otherwise     type)))
    (cons
     (case (first type)
       (signed-byte   (simplify-type-signed-byte   type))
       (unsigned-byte (simplify-type-unsigned-byte type))
       (member        (simplify-type-member type))
       ((integer single-float double-float)        (simplify-type-real type))
       ((array        simple-array  vector)        (simplify-type-array type))
       ((string       simple-string simple-base-string simple-vector bit-vector simple-bit-vector)
        #||#                                       (simplify-type-string type))
       (otherwise     (cons (first type)
                            (loop :for e :in (rest type)
                               :collect (simplify-type e))))))))

(defun simplify-typexpand-list (types)
  (declare (type list types))
   (loop :for type :in types
      :collect (simplify-type (typexpand type))))
