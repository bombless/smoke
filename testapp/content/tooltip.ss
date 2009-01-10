#lang scheme/base

(require (planet untyped/smoke:1/lib/html/browser-util)
         (planet untyped/unlib:3/string)
         "../content-base.ss")

; Controllers ------------------------------------

; request -> response
(define-controller tooltip
  init-smoke-pipeline
  (lambda (request)
    (send tooltip-page respond)))

; Components -------------------------------------

(define tooltip-page
  (singleton/cells html-page% ()
    
    (inherit set-dialog!)
    
    ; Fields -------------------------------------
    
    ; Constructor --------------------------------
    
    (super-new [component-id 'tooltip-page] 
               [title "Tooltip"])
    
    ; Methods ------------------------------------
    
    ; -> (listof (U xml (seed -> xml)))
    (define/augment (get-html-requirements)
      (list* tooltip-script
             (inner null get-html-requirements)))
    
    ; seed -> xml
    (define/augment (render seed)
      (xml (h1 "Tooltip test")
           (p "This is a visual test that would be very hard to automated. "
              "Hover over each of these tooltips and check that the tooltip appears inside the viewport. "
              "Also, try making the browser height less than the tooltip height and see if the tooltip is placed in a sensible position.")
           ,@(for/list ([index (in-range 0 50)])
               (xml (div (@ [class "tooltip-anchor"]
                            [style ,(format "clear: both; float: ~a"
                                            (if (even? index) "left" "right"))])
                         "Tooltip number " ,index
                         (div (@ [class "tooltip"] [style "background: #fff; z-index: 1"])
                              #<<ENDTEXT
Lorem ipsum in eum graeco iriure admodum, iusto epicurei his eu. No est libris dissentias, cum ex fugit eirmod eleifend. Et habeo mollis verear nam, vis in graeco mnesarchum. Menandri eloquentiam cum in, pri suavitate iracundia eu, no est quot consetetur disputando. Iudicabit adversarium signiferumque mea ut, ubique dicunt volutpat et est, mel id eius latine omnesque. At cum placerat splendide, mel diam partem integre eu.

Quod voluptaria delicatissimi nec cu, an vix nisl utroque interpretaris. Nemore perfecto eos id. Quo quis viris possit te, pri id utamur aperiam recusabo. Et eam eius habeo salutandi, mea brute graece nominati et, at eum aperiam platonem. Fugit maiorum indoctum ut qui.
ENDTEXT
                              ))))))))