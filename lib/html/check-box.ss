#lang scheme/base

(require (planet untyped/unlib:3/symbol)
         "../../lib-base.ss"
         "form-element.ss")

; Browsers only submit values for HTML checkboxes to the server when they are checked.
; The absence of a value is supposed to be enough to tell that a checkbox was left unchecked.
; This means in an AJAX update we can't tell if a box has been unchecked or if it hasn't been
; changed.
;
; To get around this we add a hidden form field called "blah-submitted", which is permanently
; set to "yes". We use the hidden field ID to check for submission and the check box ID to check
; for a truth value.

(define check-box%
  (class/cells form-element% ()
    
    (inherit get-id
             get-enabled?
             core-html-attributes)
    
    ; Fields -------------------------------------
    
    ;; (cell boolean)
    (init-cell [value #f] #:override-accessor #:override-mutator)
    
    ; (cell xml)
    (init-cell [label #f] #:accessor #:mutator)
    
    ; Constructor --------------------------------
    
    ; (listof symbol)
    (init [classes null])
    
    (super-new [classes (cons 'smoke-check-box classes)])
    
    ; Public methods -----------------------------
    
    ; -> symbol
    (define/private (get-wrapper-id)
      (symbol-append (get-id) '-hidden))
    
    ; -> symbol
    (define/private (get-hidden-id)
      (symbol-append (get-id) '-submitted))
    
    ; -> boolean
    (define/override (value-valid?)
      #t)
    
    ; -> boolean
    (define/override (value-changed?)
      (web-cell-changed? value-cell))
    
    ; seed -> xml
    (define/override (render seed)
      (define id         (get-id))
      (define wrapper-id (get-wrapper-id))
      (define hidden-id  (get-hidden-id))
      (define value      (get-value))
      (define label      (get-label))
      (xml (span (@ [id ,wrapper-id])
                 (input (@ [id    ,hidden-id]
                           [name  ,hidden-id]
                           [type  "hidden"]
                           [value "yes"]))
                 (input (@ ,(core-html-attributes seed)
                           [type "checkbox"]
                           ,(opt-xml-attr value checked "checked")))
                 ,(opt-xml label
                    " " (label (@ [for ,id]) ,label)))))
    
    ; request -> void
    (define/augment (on-request request)
      (when (and (get-enabled?) (request-binding-ref request (get-hidden-id)))
        (set-value! (and (request-binding-ref request (get-id)) #t))))
    
    ; seed -> js
    (define/override (get-on-render seed)
      (js (!dot Smoke (insertHTML (!dot Smoke (findById ,(get-wrapper-id)))
                                  "replace"
                                  ,(xml->string (render seed))))))
    
    ; seed -> js
    (define/augment (get-on-click seed)
      (define id (get-id))
      (define hidden-id (get-hidden-id))
      (js (if (!dot Smoke (findById ,id) checked)
              (!dot Smoke (setSubmitData ,id (!dot Smoke (findById ,id) value)))
              (!dot Smoke (removeSubmitData ,id)))
          (!dot Smoke (setSubmitData ,hidden-id "yes"))
          ,(inner (js) get-on-click seed)))))

; Provide statements -----------------------------

(provide check-box%)