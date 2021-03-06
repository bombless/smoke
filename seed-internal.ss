#lang scheme/base

(require net/url
         scheme/contract
         (only-in srfi/1 drop-right)
         srfi/13
         (planet dherman/json:3)
         (planet untyped/unlib:3/debug)
         "base.ss"
         "class/class.ss"
         "web-server/continuation-url.ss")

; Structure types --------------------------------

; (struct page<%> (thunk -> string))
(define-struct seed (page embed-url) #:transparent)

; (struct html-component<%> symbol (listof json-serializable))
(define-struct callback (component callback-id args) #:transparent)

; Variables --------------------------------------

; (parameter (U html-page<%> #f))
(define current-page (make-parameter #f))

; Procedures -------------------------------------

; seed callback -> string
(define (callback-url seed callback)
  (url->string
   (url->continuation-url
    (make-url #f #f #f #f #t
              (append (url-path-base (url-path (request-uri (current-request))))
                      (map (cut make-path/param <> null)
                           (list* "_"
                                  (symbol->string (send (callback-component callback) get-component-id))
                                  (symbol->string (send (callback-component callback)
                                                        verify-callback-id
                                                        (callback-callback-id callback)))
                                  (map (lambda (arg)
                                         (if (symbol? arg)
                                             (if (memq arg '(true false null))
                                                 (error "Cannot serialize the symbols 'true, 'false or 'null in a callback URL.")
                                                 (symbol->string arg))
                                             (jsexpr->json arg)))
                                       (callback-args callback)))))
              null #f)
    (send (seed-page seed) get-callback-codes))))

; request page -> (U callback #f)
(define (request->callback request page)
  (match (url-path-extension (url-path (request-uri request)))
    [(list component-id-element   ; path/param
           callback-id-element    ; path/param
           arg-elements ...)      ; (listof path/param)
     (let ([component-id (string->symbol (path/param-path component-id-element))]
           [callback-id  (string->symbol (path/param-path callback-id-element))]
           [args         (map (lambda (path/param)
                                (let ([path (path/param-path path/param)])
                                  (with-handlers ([exn? (lambda _ (string->symbol path))])
                                    (json->jsexpr path))))
                              arg-elements)])
       (make-callback (send page find-component/id component-id)
                      callback-id
                      args))]
    [#f #f]))

; Provide statements -----------------------------

(provide/contract
 [struct seed            ([page any/c] [embed-url procedure?])]
 [struct callback        ([component any/c] [callback-id symbol?] [args (listof (or/c symbol? jsexpr?))])]
 [current-page           parameter?]
 [callback-url           (-> seed? callback? string?)]
 [request->callback      (-> request? any/c (or/c callback? false/c))])
