#lang scheme/base

(require (planet untyped/unlib:3/date)
         "../../lib-base.ss"
         "browser-util.ss"
         "form-element.ss"
         "text-field.ss")

(define date-field<%>
  (interface (form-element<%>)
    get-date
    get-time-utc
    get-time-tai))

(define date-field%
  (class/cells text-field% (date-field<%>)    
    
    (inherit get-id
             get-allow-blank?
             get-enabled?
             get-placeholder)
    
    ; Fields -------------------------------------
    
    ; (cell string)
    (init-cell tz #f #:accessor #:mutator)
    
    ; (cell string)
    (init-cell date-format "~d/~m/~Y ~H:~M" #:accessor #:mutator)
    
    ; (cell boolean)
    (init-cell show-date-label? #f #:accessor #:mutator)
    
    ; (cell (U string #f))
    (init-cell date-picker-format
               (date-format->jquery-ui-date-format date-format)
               #:accessor #:mutator)
    
    ; Constructor --------------------------------
    
    (init [classes     null]
          [max-length  (date-format->max-length date-format)]
          [size        max-length]
          [placeholder (date-format->placeholder date-format)])
    
    (super-new [classes     (list* 'smoke-date-field classes)]
               [size        size]
               [max-length  max-length]
               [placeholder placeholder])
    
    ; Methods ------------------------------------
    
    ; -> string
    (define/public (get-effective-tz)
      (or (get-tz)
          (current-tz)))
    
    ; -> string
    (define/public (get-date-format-example)
      (date->string (current-date) (get-date-format)))
    
    ; -> (U date #f)
    (define/override (get-value)
      (get-date))
    
    ; -> (U date #f)
    (define/public (get-date)
      (let ([val (super get-value)]
            [fmt (get-date-format)])
        (with-handlers ([exn:fail? (lambda (exn)
                                     (raise-exn exn:smoke:form 
                                       ; We currently ignore allow-blank? in this message because it causes incompatibilities with Scaffold.
                                       ; For backwards-compatibility, Scaffold does not use allow-blank?=#f, favouring errors in the validation phase instead of the parse phase.
                                       ; This means Smoke can create misleading error messages when a field is required in Scaffold but not in Smoke.
                                       (format "Value must be in the format: ~a."
                                               (or (get-placeholder)
                                                   (get-date-format-example)))
                                       this))])
          (and val (string->date val fmt #:tz (get-effective-tz))))))
    
    ; -> (U time-utc #f)
    (define/public (get-time-utc)
      (let ([val (get-date)])
        (and val (date->time-utc val))))
    
    ; -> (U time-tai #f)
    (define/public (get-time-tai)
      (let ([val (get-date)])
        (and val (date->time-tai val))))
    
    ; date -> void
    (define/override (set-value! val)
      (let ([date (cond [(not val)       val]
                        [(date? val)     val]
                        [(time-tai? val) (time-tai->date val #:tz (get-effective-tz))]
                        [(time-utc? val) (time-utc->date val #:tz (get-effective-tz))]
                        [else            (raise-type-error 'set-value! "(U date time-utc time-tai #f)" val)])])
        (super set-value! (and date (date->string date (get-date-format) #:tz (get-effective-tz))))))
    
    ; seed -> xml
    (define/override (render seed)
      (xml ,(super render seed)
           ,(opt-xml (get-show-date-label?)
              " example: " ,(get-date-format-example))))
    
    ; seed -> js
    (define/augment (get-on-attach seed)
      (let ([fmt (get-date-picker-format)])
        (js ,(opt-js fmt
               (!dot ($ ,(format "#~a" (get-id)))
                     (datepicker (!object [dateFormat      ,fmt]
                                          [showOn          "button"]
                                          [buttonImage     "/images/jquery-ui/calendar.gif"]
                                          [buttonImageOnly #t])))
               ,(opt-js (not (get-enabled?))
                  (!dot ($ ,(format "#~a" (get-id)))
                        (datepicker "disable"))))
            ,(inner (js) get-on-attach seed))))
    
    ; seed -> js
    (define/augment (get-on-detach seed)
      (let ([fmt (get-date-picker-format)])
        (js ,(opt-js fmt
               (!dot ($ ,(format "#~a" (get-id)))
                     (datepicker "destroy")))
            ,(inner (js) get-on-detach seed))))))

; Helpers ----------------------------------------

; (U string #f) -> (U natural #f)
(define (date-format->max-length fmt)
  (and fmt (for/fold ([accum (string-length fmt)])
                     ([card (in-list (regexp-match* #px"~." fmt))])
                     (+ accum (match card
                                ["~~" -1]
                                ["~a" 2]
                                ["~A" 8]
                                ["~b" 2]
                                ["~B" 8]
                                ["~d" 1]
                                ["~e" 1]
                                ["~h" 1]
                                ["~H" 1]
                                ["~k" 1]
                                ["~m" 1]
                                ["~M" 1]
                                ["~S" 1]
                                ["~y" 1]
                                ["~Y" 3]
                                ["~z" 4]
                                [_    1])))))

; (U string #f) -> (U natural #f)
(define (date-format->size fmt)
  (and fmt (date-format->max-length fmt)))

; string -> (U string #f)
(define (date-format->jquery-ui-date-format fmt)
  (let/ec return
    (regexp-replace*
     #px"~."
     (regexp-replace* #px"'" fmt "''")
     #;(if (regexp-match? #px"^~.$" fmt)
         fmt
         (regexp-replace*
          #px"(~.)?([^~]+)(~.)?"
          (regexp-replace* #px"'" fmt "''")
          (lambda (a b c d)
            (if b
                (if d
                    (format "~a'~a'~a" b c d)
                    (format "~a'~a'" b c))
                (if d
                    (format "'~a'~a" c d)
                    (format "'~a'" c))))))
     (match-lambda
       ["~~" "~"]
       ["~a" "D"]
       ["~A" "DD"]
       ["~b" "M"]
       ["~B" "MM"]
       ["~d" "dd"]
       ["~e" "d"]
       ["~h" "M"]
       #;["~H" (return #f)]
       #;["~k" (return #f)]
       ["~m" "mm"]
       #;["~M" (return #f)]
       #;["~S" (return #f)]
       ["~y" "y"]
       ["~Y" "yy"]
       [_ (return #f)]))))

; string -> (U string #f)
(define (date-format->placeholder fmt)
  (let/ec return
    (regexp-replace*
     #px"~."
     (regexp-replace* #px"'" fmt "''")
     (match-lambda
       ["~~" "~"]
       ["~a" (return #f)]
       ["~A" (return #f)]
       ["~b" (return #f)]
       ["~B" (return #f)]
       ["~d" "DD"]
       ["~e" "DD"]
       ["~h" (return #f)]
       ["~H" "HH"]
       ["~k" "HH"]
       ["~m" "MM"]
       ["~M" "MM"]
       ["~S" "SS"]
       ["~y" "YY"]
       ["~Y" "YYYY"]
       [_    (return #f)]))))

; Provide statements -----------------------------

(provide date-field<%>
         date-field%)