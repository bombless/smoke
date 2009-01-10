#lang scheme/base

(require scheme/match
         (only-in srfi/1/list delete)
         srfi/26/cut
         (planet untyped/unlib:3/string)
         (planet untyped/unlib:3/symbol)
         "../../lib-base.ss"
         "form-element.ss"
         "html-element.ss")

; Both radio-group% and all radio-button%s must be added as children of
; the component in which they are rendered.

(define radio-group%
  (class/cells form-element% ()
    
    (inherit get-id
             get-enabled?
             get-child-components)
    
    ; Fields -------------------------------------
    
    ; (cell (U radio-button% #f))
    (cell [selected #f] #:accessor)
    
    ; (cell (list-of radio-button%))
    (init-cell [buttons null] #:accessor #:mutator)
    
    ; Constructor ------------------------------
    
    ; any
    (init [selected #f])
    
    (when selected (set-selected! selected))
    
    (super-new)
    
    ; Public methods -----------------------------
    
    ; -> any
    (define/override (get-value)
      (and (get-selected)
           (send (get-selected) get-value)))
    
    ; any -> void
    (define/override (set-value! value)
      (set-selected! (ormap (lambda (button)
                              (and (equal? (send button get-value) value) button))
                            (get-buttons))))
    
    ; radio-button% -> void
    (define/public (set-selected! button)
      (if (or (not button) (is-a? button radio-button%))
          (web-cell-set! selected-cell button)
          (raise-exn exn:fail:contract
            (format "Expected (U radio-button% #f), received ~s" button))))
  
    ; symbol -> void
    (define/public (set-selected/id! id)
      (set-selected! (ormap (lambda (button)
                              (and (equal? (send button get-id) id) button))
                            (get-buttons))))
    
    ; -> boolean
    (define/override (value-changed?)
      (web-cell-changed? selected-cell))
    
    ; seed -> xml
    (define/override (render seed)
      (xml))
    
    ; request -> void
    (define/augment (on-request request)
      (when (get-enabled?)
        (let ([binding (request-binding-ref request (get-id))])
          (when binding (set-selected/id! (string->symbol binding))))))))

(define radio-button%
  (class/cells html-element% ()
    
    (inherit get-id
             core-html-attributes)
    
    ; Fields -----------------------------------
    
    ; (cell radio-group%)
    (cell [group #f] #:accessor)
    
    ; (cell any)
    (init-cell [value #f] #:accessor #:mutator)
    
    ; (cell xml)
    (init-cell [label #f] #:accessor #:mutator)
    
    ; Constructor ------------------------------
    
    ; button-group<%>
    (init [group #f])
    
    ; (listof symbol)
    (init [classes null])
    
    (when group (set-group! group))
    (super-new [classes (cons 'smoke-radio-button classes)])
    
    ; Public methods ---------------------------
    
    ; radio-group% -> void
    (define/public (set-group! new-group)
      (define old-group (get-group))
      (when old-group (send old-group set-buttons! (delete this (send old-group get-buttons))))
      (web-cell-set! group-cell new-group)
      (when new-group (send new-group set-buttons! (cons this (send new-group get-buttons)))))
    
    ; seed -> xml
    (define/override (render seed)
      (define id       (get-id))
      (define group    (get-group))
      (define name     (send group get-id))
      (define value    (get-id))
      (define label    (get-label))
      (define checked? (equal? (get-value) (send group get-value)))
      (xml (input (@ ,@(core-html-attributes seed)
                     [type  "radio"]
                     [name  ,name]
                     [value ,value]
                     ,@(if checked? (xml-attrs [checked "checked"]) null)))
           ,(opt-xml label
              " " (label (@ [for ,id]) ,label))))
    
    ; seed -> js
    (define/augment (get-on-click seed)
      (define id (send (get-group) get-id))
      (define value (get-id))
      (js (!dot Smoke (setSubmitData ,id ,value))
          ,(inner (js) get-on-click seed)))))

; Provide statements -----------------------------

(provide radio-group%
         radio-button%)