#lang scheme/base

(require (for-template scheme/base
                       "../base.ss")
         (planet untyped/unlib:3/syntax)
         "../base.ss")

; Seed structure ---------------------------------

; (struct (listof syntax) (listof syntax) boolean boolean)
;
; Records the accumulation of syntax as a (class/cells ...) or
; (mixin/cells ...) form is built up.
(define-struct seed (body-clause-stxs foot-clause-stxs has-super-new? has-inspector?) #:transparent)

; -> seed
(define (create-seed)
  (make-seed null null #f #f))

; seed syntax -> seed
(define (add-body seed stx)
  (make-seed (cons stx (seed-body-clause-stxs seed))
             (seed-foot-clause-stxs seed)
             (seed-has-super-new? seed)
             (seed-has-inspector? seed)))

; seed syntax -> seed
(define (add-foot seed stx)
  (make-seed (seed-body-clause-stxs seed)
             (cons stx (seed-foot-clause-stxs seed))
             (seed-has-super-new? seed)
             (seed-has-inspector? seed)))

; seed syntax -> seed
(define (record-super-new seed)
  (make-seed (seed-body-clause-stxs seed)
             (seed-foot-clause-stxs seed)
             #t
             (seed-has-inspector? seed)))

; seed syntax -> seed
(define (record-inspector seed)
  (make-seed (seed-body-clause-stxs seed)
             (seed-foot-clause-stxs seed)
             (seed-has-super-new? seed)
             #t))

; Syntax transformers ----------------------------

; syntax seed -> seed
(define (expand-clause clause-stx seed)
  (syntax-case* clause-stx (field fields cell cells init-field init-fields init-cell init-cells super-new inspect
                             define/augment define/augment-final define/augride define/overment
                             define/override define/override-final define/internal define/public
                             define/public-final define/pubment) symbolic-identifier=?
    [(field arg ...)                     (expand-field-clause clause-stx seed)]
    [(cell arg ...)                      (expand-cell-clause clause-stx seed)]
    [(init-field arg ...)                (expand-init-field-clause clause-stx seed)]
    [(init-cell arg ...)                 (expand-init-cell-clause clause-stx seed)]
    [(fields ([f ...] ...) arg ...)      (foldl expand-field-clause seed (syntax->list #'((field [f ...] arg ...) ...)))]
    [(cells  ([c ...] ...) arg ...)      (foldl expand-cell-clause seed (syntax->list #'((cell [c ...] arg ...) ...)))]
    [(init-fields ([f ...] ...) arg ...) (foldl expand-init-field-clause seed (syntax->list #'((field f ... arg ...) ...)))]
    [(init-cells  ([c ...] ...) arg ...) (foldl expand-init-cell-clause seed (syntax->list #'((cell c ... arg ...) ...)))]
    [(super-new arg ...)                 (add-body (record-super-new seed) clause-stx)]
    [(inspect arg ...)                   (add-body (record-inspector seed) clause-stx)]
    [(define/augment arg ...)            (expand-method-clause clause-stx seed)]
    [(define/augment-final arg ...)      (expand-method-clause clause-stx seed)]
    [(define/augride arg ...)            (expand-method-clause clause-stx seed)]
    [(define/overment arg ...)           (expand-method-clause clause-stx seed)]
    [(define/override arg ...)           (expand-method-clause clause-stx seed)]
    [(define/override-final arg ...)     (expand-method-clause clause-stx seed)]
    [(define/internal arg ...)           (expand-method-clause clause-stx seed)]
    [(define/public arg ...)             (expand-method-clause clause-stx seed)]
    [(define/public-final arg ...)       (expand-method-clause clause-stx seed)]
    [(define/pubment arg ...)            (expand-method-clause clause-stx seed)]
    [other                               (add-body seed clause-stx)]))

; syntax seed -> seed
(define (expand-field-clause clause-stx seed)
  (syntax-case clause-stx ()
    [(_ [id value] kw ...)
     (identifier? #'id)
     (expand-keywords #'id #'(kw ...) #f (add-body seed #'(field [id value])))]))

; syntax seed -> seed
(define (expand-cell-clause clause-stx seed)
  (syntax-case clause-stx ()
    [(_ [id value] kw ...)
     (identifier? #'id)
     (with-syntax ([cell-id (make-cell-id #'id)])
       (expand-keywords #'id #'(kw ...) #t 
                        (add-foot (add-body seed #'(field [cell-id (parameterize ([web-cell-id-prefix 'id])
                                                                     (make-web-cell value))]))
                                  #'(send this register-web-cell-field! cell-id))))]))

; syntax seed -> seed
(define (expand-init-field-clause clause-stx seed)
  (syntax-case clause-stx ()
    [(_ [id value] kw ...)
     (identifier? #'id)
     (expand-keywords #'id #'(kw ...) #f (add-body seed #'(init-field [id value])))]
    [(_ id kw ...)         
     (identifier? #'id)
     (expand-keywords #'id #'(kw ...) #f (add-body seed #'(init-field id)))]))

; syntax seed -> seed
(define (expand-init-cell-clause clause-stx seed)
  (syntax-case clause-stx ()
    [(_ [id value] kw ...) 
     (with-syntax ([cell-id (make-cell-id #'id)])
       (expand-keywords #'id #'(kw ...) #t 
                        (add-foot (add-body (add-body (add-body seed #'(field [cell-id (parameterize ([web-cell-id-prefix 'id])
                                                                                         (make-web-cell #f))]))
                                                      #'(init [id value]))
                                            #'(web-cell-set! cell-id id))
                                  #'(send this register-web-cell-field! cell-id))))]
    [(_ id kw ...)
     (identifier? #'id)
     (with-syntax ([cell-id (make-cell-id #'id)])
       (expand-keywords #'id #'(kw ...) #t 
                        (add-foot (add-body (add-body (add-body seed #'(field [cell-id (parameterize ([web-cell-id-prefix 'id])
                                                                                         (make-web-cell #f))]))
                                                      #'(init id))
                                            #'(web-cell-set! cell-id id))
                                  #'(send this register-web-cell-field! cell-id))))]))

; syntax syntax boolean seed -> seed
(define (expand-keywords id-stx kw-stx cell? seed)
  (syntax-case kw-stx ()
    [() seed]
    [(kw other ...)
     (call-with-values
      (cut match (syntax->datum #'kw)
           ['#:child             (expand-child-keyword          id-stx #'(other ...) cell? seed)]
           ['#:children          (expand-children-keyword       id-stx #'(other ...) cell? seed)]
           ['#:optional-child    (expand-optional-child-keyword id-stx #'(other ...) cell? seed)]
           ['#:accessor          (expand-accessor-keyword       id-stx #'(other ...) cell? #f seed)]
           ['#:mutator           (expand-mutator-keyword        id-stx #'(other ...) cell? #f seed)]
           ['#:override-accessor (expand-accessor-keyword       id-stx #'(other ...) cell? #t seed)]
           ['#:override-mutator  (expand-mutator-keyword        id-stx #'(other ...) cell? #t seed)]
           [other                (error (format "Expected keyword, received ~s" other))])
      (cut expand-keywords id-stx <> cell? <>))]))

; syntax syntax boolean seed -> syntax seed
(define (expand-child-keyword id-stx other-stx cell? seed)
  (values other-stx 
          (with-syntax ([id id-stx] [cell-id (make-cell-id id-stx)])
            (add-foot seed #`(send this register-children-thunk! 'id
                                   #,(if cell?
                                         #`(lambda () (list (web-cell-ref cell-id)))
                                         #`(lambda () (list id))))))))

; syntax syntax boolean seed -> syntax seed
(define (expand-children-keyword id-stx other-stx cell? seed)
  (values other-stx 
          (with-syntax ([id id-stx] [cell-id (make-cell-id id-stx)])
            (add-foot seed #`(send this register-children-thunk! 'id
                                   #,(if cell?
                                         #`(lambda () (web-cell-ref cell-id))
                                         #`(lambda () id)))))))

; syntax syntax boolean seed -> syntax seed
(define (expand-optional-child-keyword id-stx other-stx cell? seed)
  (values other-stx 
          (with-syntax ([id id-stx] [cell-id (make-cell-id id-stx)])
            (add-foot seed #`(send this register-children-thunk! 'id
                                   #,(if cell?
                                         #`(lambda ()
                                             (let ([child (web-cell-ref cell-id)])
                                               (if child (list child) null)))
                                         #`(lambda ()
                                             (if id (list id) null))))))))

; syntax syntax boolean boolean seed -> syntax seed
(define (expand-accessor-keyword id-stx other-stx cell? override? seed)
  (with-syntax ([define/whatever (if override?
                                     #'define/override
                                     #'define/public)]
                [accessor-body   (if cell? 
                                     #`(web-cell-ref #,(make-cell-id id-stx))
                                     id-stx)])
    (syntax-case other-stx ()
      [(accessor-id other ...)
       (identifier? #'accessor-id)
       (values #'(other ...) (add-body seed #`(define/whatever (accessor-id) accessor-body)))]
      [(other ...)    
       (with-syntax ([accessor-id (make-id id-stx 'get- id-stx)])
         (values other-stx (add-body seed #`(define/whatever (accessor-id) accessor-body))))])))

; syntax syntax boolean boolean seed -> syntax seed
(define (expand-mutator-keyword id-stx other-stx cell? override? seed)
  (with-syntax ([define/whatever (if override?
                                     #'define/override
                                     #'define/public)]
                [mutator-body    (if cell? 
                                     #`(web-cell-set! #,(make-cell-id id-stx) val)
                                     #`(set! #,id-stx val))])
    (syntax-case other-stx ()
      [(mutator-id other ...)
       (identifier? #'mutator-id)
       (values #'(other ...) (add-body seed #`(define/whatever (mutator-id val) mutator-body)))]
      [(other ...)    
       (with-syntax ([mutator-id (make-id id-stx 'set- id-stx '!)])
         (values other-stx (add-body seed #`(define/whatever (mutator-id val) mutator-body))))])))

; syntax seed -> seed
(define (expand-method-clause clause-stx seed)
  (syntax-case clause-stx ()
    [(define/whatever key (id arg ...) expr ...)
     (and (identifier? #'id)
          (keyword? (syntax->datum #'key)))
     (let ([key-datum (syntax->datum #'key)])
       (cond [(equal? key-datum '#:callback)
              (add-foot (add-body seed #'(define/whatever (id arg ...) expr ...))
                        #'(send this register-callback! 'id (lambda args (id . args)) #t))]
             [(equal? key-datum '#:callback/return)
              (add-foot (add-body seed #'(define/whatever (id arg ...) expr ...))
                        #'(send this register-callback! 'id (lambda args (id . args)) #f))]
             [else (raise-syntax-error #f "bad method keyword:" clause-stx #'key)]))]
    [(define/whatever key (id arg ... . rest) expr ...)
     (and (identifier? #'id)
          (keyword? (syntax->datum #'key)))
     (let ([key-datum (syntax->datum #'key)])
       (cond [(equal? key-datum '#:callback)
              (add-foot (add-body seed #'(define/whatever (id arg ... . rest) expr ...))
                        #'(send this register-callback! 'id (lambda args (id . args)) #t))]
             [(equal? key-datum '#:callback/return)
              (add-foot (add-body seed #'(define/whatever (id arg ... . rest) expr ...))
                        #'(send this register-callback! 'id (lambda args (id . args)) #f))]
             [else (raise-syntax-error #f "bad method keyword:" clause-stx #'key)]))]
    [other (add-body seed clause-stx)]))

; Helpers ----------------------------------------

; syntax -> syntax
(define (make-cell-id id-stx)
  (make-id id-stx id-stx '-cell))

; Provide statements -----------------------------

(provide (except-out (struct-out seed) make-seed))

(provide/contract
 [rename create-seed make-seed (-> seed?)]
 [expand-clause                (-> syntax? seed? seed?)]) 