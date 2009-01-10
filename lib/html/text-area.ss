#lang scheme/base

(require "../../lib-base.ss"
         "text-input.ss")

(define text-area%
  (class/cells text-input% ()
    
    (inherit get-id
             get-raw
             set-raw!
             get-enabled?
             core-html-attributes)
    
    ; Fields -----------------------------------
    
    ; (cell (U natural #f))
    (init-cell [rows #f] #:accessor #:mutator)
    
    ; (cell (U natural #f))
    (init-cell [cols #f] #:accessor #:mutator)

    ; Constructor ------------------------------
    
    ; (listof symbol)
    (init [classes null])
    
    (super-new [classes (cons 'smoke-text-area classes)])
    
    ; Public methods ---------------------------
    
    ; seed -> xml
    (define/override (render seed)
      (define id   (get-id))
      (define rows (get-rows))
      (define cols (get-cols))
      (define raw  (get-raw))
      (xml (textarea (@ ,(core-html-attributes seed)
                        ,(opt-xml-attr rows)
                        ,(opt-xml-attr cols))
                     ,raw)))
    
    ; request -> void
    (define/augride (on-request request)
      (when (get-enabled?)
        (let ([binding (request-binding-ref request (get-id))])
          (when binding 
            (set-raw! binding)))))))

; Provide statements -----------------------------

(provide text-area%)