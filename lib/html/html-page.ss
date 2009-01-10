#lang scheme/base

(require (only-in srfi/1 
                  delete
                  delete-duplicates)
         (only-in (planet schematics/schemeunit:2/text-ui)
                  display-exn)
         (planet untyped/unlib:3/list)
         (planet untyped/unlib:3/symbol)
         "../../lib-base.ss"
         "../page.ss"
         "browser-util.ss"
         "html-box.ss"
         "html-component.ss"
         "html-element.ss")

(define html-page<%>
  (interface (page<%>)
    get-doctype      ; -> xml
    get-lang         ; -> string
    get-title))      ; -> frame

(define html-page-mixin
  (mixin/cells (page<%> html-element<%>) (html-page<%>)
    
    (inherit core-html-attributes
             get-all-components
             get-on-attach
             get-child-components
             get-component-id
             get-content-type
             get-dirty-components
             get-html-requirements/fold
             get-http-code
             get-http-headers
             get-http-status
             get-http-timestamp
             get-id
             get-js-requirements/fold)
    
    ; Fields -------------------------------------
    
    ; (cell xml)
    (init-cell [doctype xhtml-1.0-transitional-doctype] #:accessor #:mutator)
    
    ; (cell string)
    (init-cell [lang "en"] #:accessor #:mutator)
    
    ; (cell string)
    (init-cell [title "Untitled"] #:accessor #:mutator)
    
    ; (cell string)
    (init-cell [description #f] #:accessor #:mutator)
    
    ; (cell string)
    (init-cell [keywords #f] #:accessor #:mutator)
    
    ; (cell string)
    (init-cell [generator "Smoke by Untyped"] #:accessor #:mutator)
    
    ; (cell boolean)
    (init-cell [debug-javascript? #f] #:accessor #:mutator)
    
    ; (cell (U (list integer integer integer) #f))
    (cell [callback-codes #f] #:accessor #:mutator)
    
    ; (cell (listof (U xml (seed -> xml))))
    (cell [current-html-requirements null] #:accessor #:mutator)
    
    ; (cell (listof (U js (seed -> js))))
    (cell [current-js-requirements null] #:accessor #:mutator)
        
    ; string
    (init [content-type "text/html; charset=utf-8"])
    
    ; (listof symbol)
    (init [classes null])
    
    (super-new [classes (cons 'smoke-html-page classes)] [content-type content-type])
    
    ; html-div%
    ;
    ; This placeholder acts to prevent the whole page content being
    ; refreshed when a dialog is added or removed.
    (field [dialog-placeholder (new html-box%
                                    [id      (symbol-append (get-id) '-dialog-placeholder)]
                                    [classes '(smoke-html-page-dialog-placeholder)])]
      #:child #:accessor #:mutator)

    ; Accessors ----------------------------------
    
    ; -> symbol
    (define/public (get-form-id)
      (symbol-append (get-id) '-form))
    
    ; -> (U html-dialog% #f)
    (define/public (get-dialog)
      (send dialog-placeholder get-content))
    
    ; (U html-dialog% #f) -> void
    (define/public (set-dialog! new-dialog)
      (define old-dialog (send dialog-placeholder get-content))
      (when old-dialog (send old-dialog set-page! #f))
      (send dialog-placeholder set-content! new-dialog)
      (when new-dialog (send new-dialog set-page! this)))
    
    ; Response generation ------------------------
    
    ; -> (listof (U xml (seed -> xml)))
    (define/augment (get-html-requirements)
      (assemble-list
       #;[(deploying-for-development?) firebug-script]
       [#t                           smoke-styles]
       [#t                           ,@(inner null get-html-requirements)]))
    
    ;  [#:forward? boolean] -> any
    (define/override (respond #:forward? [forward? #f])
      (with-handlers ([exn? (lambda (exn)
                              (log-debug* "Frame unserializable" 
                                          (frame-id (current-frame))
                                          "unserializable"
                                          (exn-message exn)))])
        (log-debug* "Frame serializable"
                    (frame-id (current-frame))
                    (format "~a bytes"
                            (let ([out (open-output-bytes)])
                              (write (frame-serialize (current-frame)) out)
                              (bytes-length (get-output-bytes out))))))
      (unless (current-request)
        (error "No current HTTP request to respond to."))
      ; boolean
      (let ([push-frame?
             (and (not (ajax-request? (current-request)))
                  (not (eq? (request-method (current-request)) 'post)))])
        (when forward?
          (clear-continuation-table!))
        (parameterize ([current-page this])
          (when push-frame?
            (resume-from-here))
          (send/suspend/dispatch (make-response-generator) #:push-frame? push-frame?))))
    
    ; -> (embed-url -> response)
    ;
    ; Makes a response-generator for use with send/suspend/dispatch. The response type varies 
    ; according to the type of request being handled:
    ;
    ;   - full page requests yield complete pages of XHTML;
    ;   - AJAX requests originating from event handlers in this page yield Javascript responses
    ;     that refresh appropriate parts of the page;
    ;   - AJAX requests originating from event handlers in other pages yield Javascript responses
    ;     that redirect the browser to this page (triggering a full page refresh).
    ;
    ; #:script allows the caller to specify a block of Javascript to run after the page has been 
    ; displayed or changed. This is useful for, for example, showing a message to the user or
    ; performing some update action. The script is executed after all other script execution and
    ; content rendering.
    (define/override (make-response-generator)
      (if (ajax-request? (current-request))
          (if (equal? (ajax-request-page-id (current-request)) (get-component-id))
              (make-ajax-response-generator)
              (make-ajax-redirect-response-generator))
          (if (eq? (request-method (current-request)) 'post)
              (make-full-redirect-response-generator)
              (make-full-response-generator))))
    
    ; -> (embed-url -> response)
    ;
    ; Makes a response-generator that creates a complete XHTML response for this page.
    (define/public (make-full-response-generator)
      (lambda (embed-url)
        ; seed
        (define seed (make-seed this embed-url))
        (set-callback-codes! (make-callback-codes seed))
        ; Store the initial requirements for the page:
        (set-current-html-requirements! (delete-duplicates (get-html-requirements/fold)))
        (set-current-js-requirements! (delete-duplicates (get-js-requirements/fold)))
        ; Call render before get-on-attach for consistency with AJAX responses:
        (let ([code      (get-http-code)]
              [message   (get-http-status)]
              [seconds   (get-http-timestamp)]
              [headers   (get-http-headers)]
              [mime-type (get-content-type)]
              [content   (render seed)])
          ; response
          (make-xml-response
           #:code      code
           #:message   message
           #:seconds   seconds
           #:headers   headers
           #:mime-type mime-type
           (xml ,(get-doctype)
                (html (@ [xmlns "http://www.w3.org/1999/xhtml"] [lang ,(get-lang)])
                      (head (meta (@ [http-equiv "Content-Type"] [content ,(get-content-type)]))
                            (script (@ [type "text/javascript"] [src "/scripts/jquery/jquery.js"]))
                            (script (@ [type "text/javascript"] [src "/scripts/smoke/smoke.js"]))
                            ,(opt-xml (get-title)
                               (title ,(get-title)))
                            ,(render-head seed)
                            ,@(render-requirements (get-current-html-requirements) seed)
                            (script (@ [type "text/javascript"])
                                    (!raw "\n// <![CDATA[\n")
                                    (!raw ,(js ((function ($)
                                                  (!dot ($ document)
                                                        (ready (function ()
                                                                 (!dot Smoke (initialize ,(get-component-id)
                                                                                         ,(get-form-id)
                                                                                         (function ()
                                                                                           ; Init scripts:
                                                                                           ,@(render-requirements (get-current-js-requirements) seed)
                                                                                           ; Attach scripts:
                                                                                           ,(get-on-attach seed))))))))
                                                jQuery)))
                                    (!raw "\n// ]]>\n")))
                      (body (@ ,@(core-html-attributes seed)) ,content)))))))
    
    ; -> (embed-url -> response)
    ;
    ; Makes a response-generator that creates an AJAX Javascript response that 
    ; refreshes appropriate parts of this page.
    (define/public (make-ajax-response-generator)
      (lambda (embed-url)
        ; seed
        (define seed (make-seed this embed-url))
        ; response
        (with-handlers ([exn? (lambda (exn)
                                (display-exn exn)
                                (make-js-response 
                                 #:code 500 #:message "Internal Error"
                                 (js ((!dot console log) "An error has occurred. Talk to your system administrator."))))])
          (let ([new-html-requirements (filter-new-requirements (get-current-html-requirements) (get-html-requirements/fold))]
                [new-js-requirements   (filter-new-requirements (get-current-js-requirements)   (get-js-requirements/fold))])
            (unless (null? new-html-requirements)
              (set-current-html-requirements! (append (get-current-html-requirements) new-html-requirements)))
            (unless (null? new-js-requirements)
              (set-current-js-requirements! (append (get-current-js-requirements) new-js-requirements)))
            (parameterize ([render-pretty-javascript? #t])
              (make-js-response
               (js ((function ($)
                      ,(opt-js (not (null? new-html-requirements))
                         (!dot ($ (!dot Smoke documentHead))
                               (append ,(xml->string (xml ,@(render-requirements new-html-requirements seed))))))
                      ,@(render-requirements new-js-requirements seed)
                      ,@(map (cut send <> get-on-refresh seed)
                             (get-dirty-components)))
                    jQuery))))))))
    
    ; -> (embed-url -> response)
    ;
    ; This response is sent as the first response from any page. It sets up
    ; a top web frame and makes sure that any AJAX operations the user performs
    ; aren't lost if they hit Reload.
    (define/public (make-full-redirect-response-generator)
      (lambda (embed-url)
        ; seed
        (define seed (make-seed this embed-url))
        (make-html-response
         #:code      301 
         #:message   "Moved Permanently"
         #:mime-type #"text/html"
         #:headers   (cons (make-header #"Location" (string->bytes/utf-8 (embed/thunk seed (cut respond))))
                           no-cache-http-headers)
         (xml))))
    
    ; -> (embed-url -> response)
    ;
    ; Makes a response-generator that redirects the browser to this page.
    ;
    ; When this procedure is called, the current frame should be a child of
    ; the AJAX frame of the page. The rendering seed is set up to use the
    ; AJAX frame as the base frame for subsequent requests. The current frame
    ; is squeezed into the AJAX frame right before the response is sent.
    (define/public (make-ajax-redirect-response-generator)
      (lambda (embed-url)
        ; seed
        (define seed (make-seed this embed-url))
        ; response
        (make-js-response 
         (js (= (!dot window location)
                ,(embed/thunk seed (cut respond)))))))
    
    ; seed -> xml
    (define/public (render-head seed)
      (xml))
    
    ; seed -> xml
    (define/overment (render seed)
      (xml (form (@ [id             ,(get-form-id)] 
                    [class          "smoke-html-page-form"]
                    [method         "post"]
                    [enctype        "multipart/form-data"]
                    [accept-charset "utf-8"]
                    [action         "javascript:void(0)"])
                 ,(inner (xml "Page under construction.") render seed)
                 ,(send dialog-placeholder render seed))))
    
    ; seed -> js
    (define/override (get-on-render seed)
      (js (!dot Smoke (insertHTML (!dot Smoke (findById ,(get-id)))
                                  "children"
                                  ,(xml->string (render seed))))))))

(define html-page%
  (class/cells (html-page-mixin (page-mixin html-element%)) ()))

; Helpers ----------------------------------------

; (listof requirement) (listof requirement) -> (listof requirement)
(define (filter-new-requirements prev-reqs curr-reqs)
  (filter-map (lambda (req)
                (and (not (memq req prev-reqs))
                     req))
              curr-reqs))

; (listof (U any (seed -> any))) seed -> (listof any)
(define (render-requirements reqs seed)
  (map (lambda (req)
         (if (procedure? req)
             (req seed)
             req))
       reqs))

; Provide statements -----------------------------

(provide html-page<%>
         html-page-mixin
         html-page%)