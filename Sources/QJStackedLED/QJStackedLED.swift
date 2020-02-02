//
//  QJStackedLED.swift
//  QJStackedLED
//
//  Created by Mike Manzo on 02/02/20.
//  Copyright © 2020 Mike Manzo. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
    import UIKit

    public typealias QJViewController = UIViewController
    public typealias QJColor = UIColor
    public typealias QJFont = UIFont
    public typealias QJView = UIView
#elseif os(macOS)
    import AppKit

    public typealias QJViewController = NSViewController
    public typealias QJColor = NSColor
    public typealias QJFont = NSFont
    public typealias QJView = NSView
#endif

/// A view for showing a single number on an LED display
@IBDesignable
open class QJStackedLED: QJView {
    let controlDescription = "Stacked LED Control"

    /// Whether to maintain a view of local maximums
    @IBInspectable open var holdPeak: Bool = false {
        didSet { updateControl() }
    }
    
    /// This applies a gradient style to the rendering
    @IBInspectable open var litEffect: Bool = true {
        didSet { updateControl() }
    }
    
    /// If `true` then render top-to-bottom or right-to-left
    @IBInspectable open var reverseDirection: Bool = false {
        didSet { updateControl() }
    }
    
    /// The quantity to be rendered
    @IBInspectable open var value: Double = 0.0 {
        didSet {
            var redraw = false
            // Point at which bars start lighting up
            let newOnIdx = (value >= minLimit) ? 0 : numBars
            if onIdx != newOnIdx {
                onIdx = newOnIdx
                redraw = true
            }
            // Point at which bars are no longer lit
            let newOffIdx = Int(((value - minLimit) / (maxLimit - minLimit)) * Double(numBars))
            if newOffIdx != offIdx {
                offIdx = newOffIdx
                redraw = true
            }
            // Are we doing peak?
            if holdPeak && value > peakValue {
                peakValue = value
                peakBarIdx = min(offIdx, numBars - 1)
            }
            // Redraw the display?
            if redraw {
                updateControl()
            }
        }
    }

    /// The local maximum for `value`
    @IBInspectable open var peakValue: Double = 0.0 {
        didSet { updateControl() }
    }
    
    /// The highest possible amount for `value`
    @IBInspectable open var maxLimit: Double = 1.0 {
        didSet { updateControl() }
    }
    
    /// The lowest possible amount for `value`, must be less than `maxLimit`
    @IBInspectable open var minLimit: Double = 0.0 {
        didSet { updateControl() }
    }

    /// A quantity for `value` which will render in a special color
    @IBInspectable open var warnThreshold: Double = 0.6 {
        didSet {
            if !warnThreshold.isNaN && warnThreshold > 0.0 {
                warningBarIdx = Int(warnThreshold * Double(numBars))
            } else {
                warningBarIdx = -1
            }
        }
    }

    /// A quantity for `value` which will render in a special color
    @IBInspectable open var dangerThreshold: Double = 0.8 {
        didSet {
            if !dangerThreshold.isNaN && dangerThreshold > 0.0 {
                dangerBarIdx = Int(dangerThreshold * Double(numBars))
            } else {
                dangerBarIdx = -1
            }
        }
    }

    /// The number of discrete segments to render
    @IBInspectable open var numBars: Int = 10 {
        didSet {
            peakValue = -.infinity // force it to be updated w/new bar index
            // Update thresholds
            value = 1 * value
            warnThreshold = 1 * warnThreshold
            dangerThreshold = 1 * dangerThreshold
        }
    }

    /// Outside border color
    @IBInspectable open var outerBorderColor: QJColor = QJColor.gray {
        didSet { updateControl() }
    }
    
    /// Inside border color
    @IBInspectable open var innerBorderColor: QJColor = QJColor.black {
        didSet { updateControl() }
    }
    
    /// The rendered segment color before reaching the warning threshold
    @IBInspectable open var normalColor: QJColor = QJColor.green {
        didSet { updateControl() }
    }
    
    /// The rendered segment color after reaching the warning threshold
    @IBInspectable open var warningColor: QJColor = QJColor.yellow {
        didSet { updateControl() }
    }
    
    /// The rendered segment color after reaching the danger threshold
    @IBInspectable open var dangerColor: QJColor = QJColor.red {
        didSet { updateControl() }
    }

    fileprivate var onIdx = 0
    fileprivate var offIdx = 0
    fileprivate var peakBarIdx = -1
    fileprivate var warningBarIdx = 6
    fileprivate var dangerBarIdx = 8

    fileprivate func updateControl() {
        #if os(iOS) || os(tvOS)
            setNeedsDisplay()
        #elseif os(macOS)
            display()
        #endif
    }
    
    fileprivate func setup() {
        #if os(iOS) || os(tvOS)
            clearsContextBeforeDrawing = false
            isOpaque = false
            backgroundColor = QJColor.black
        #elseif os(macOS)
            wantsLayer = true
        self.layer?.backgroundColor = QJColor.black.cgColor
        #endif
    }

    /// QJView initializer
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    /// QJView initializer
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    /// Resets peak value
    public func resetPeak() {
        peakValue = -.infinity
        peakBarIdx = -1
        #if os(iOS) || os(tvOS)
            setNeedsDisplay()
        #elseif os(macOS)
            display()
        #endif
    }

    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        #if os(iOS) || os(tvOS)
            setNeedsDisplay()
        #elseif os(macOS)
            display()
        #endif
    }
    
    /// Draw the gauge
    override open func draw(_ rect: CGRect) {
        var ctx: CGContext
        // Graphics context
        var rectBounds: CGRect
        var rectBar = CGRect()
        // Rectangle for individual light bar
        var barSize: Int
        // Size (width or height) of each LED bar
        // How is the bar oriented?
        rectBounds = self.bounds
        let isVertical: Bool = (rectBounds.size.height >= rectBounds.size.width)
        if isVertical {
            // Adjust height to be an exact multiple of bar
            barSize = Int(rectBounds.size.height / CGFloat(numBars))
            rectBounds.size.height = CGFloat(barSize * numBars)
        }
        else {
            // Adjust width to be an exact multiple
            barSize = Int(rectBounds.size.width / CGFloat(numBars))
            rectBounds.size.width = CGFloat(barSize * numBars)
        }
        // Compute size of bar
        rectBar.size.width = isVertical ? rectBounds.size.width - 2 : CGFloat(barSize)
        rectBar.size.height = isVertical ? CGFloat(barSize) : rectBounds.size.height - 2
        // Get stuff needed for drawing
        #if os(iOS) || os(tvOS)
            ctx = UIGraphicsGetCurrentContext()!
        #elseif os(macOS)
            ctx = NSGraphicsContext.current!.cgContext
        #endif
            ctx.clear(self.bounds)

        // Fill background
        #if os(iOS) || os(tvOS)
            ctx.setFillColor(backgroundColor!.cgColor)
        #elseif os(macOS)
            ctx.setFillColor(layer!.backgroundColor!)
        #endif

        ctx.fill(rectBounds)
        // Draw LED bars
        ctx.setStrokeColor(innerBorderColor.cgColor)
        ctx.setLineWidth(1.0)
        for iX in 0..<numBars {
            // Determine position for this bar
            if reverseDirection {
                // Top-to-bottom or right-to-left
                rectBar.origin.x = (isVertical) ? rectBounds.origin.x + 1 : (rectBounds.maxX - CGFloat((iX + 1) * barSize))
                rectBar.origin.y = (isVertical) ? (rectBounds.minY + CGFloat(iX * barSize)) : rectBounds.origin.y + 1
            }
            else {
                // Bottom-to-top or right-to-left
                rectBar.origin.x = (isVertical) ? rectBounds.origin.x + 1 : (rectBounds.minX + CGFloat(iX * barSize))
                rectBar.origin.y = (isVertical) ? (rectBounds.maxY - CGFloat((iX + 1) * barSize)) : rectBounds.origin.y + 1
            }
            // Draw top and bottom borders for bar
            ctx.addRect(rectBar)
            ctx.strokePath()
            // Determine color of bar
            var clrFill: QJColor = normalColor
            if dangerBarIdx >= 0 && iX >= dangerBarIdx {
                clrFill = dangerColor
            }
            else if warningBarIdx >= 0 && iX >= warningBarIdx {
                clrFill = warningColor
            }
            // Determine if bar should be lit
            let lit: Bool = ((iX >= onIdx && iX < offIdx) || iX == peakBarIdx)
            // Fill the interior of the bar
            ctx.saveGState()
            let rectFill: CGRect = rectBar.insetBy(dx: 1.0, dy: 1.0)
            let clipPath: CGPath = CGPath(rect: rectFill, transform: nil)
            ctx.addPath(clipPath)
            ctx.clip()
            self.drawBar(ctx, withRect: rectFill, andColor: clrFill, lit: lit)
            ctx.restoreGState()
        }
        // Draw border around the control
        ctx.setStrokeColor(outerBorderColor.cgColor)
        ctx.setLineWidth(2.0)
        ctx.addRect(rectBounds.insetBy(dx: 1, dy: 1))
        ctx.strokePath()
    }

    /// Draw one of the bar segments inside the gauge
    fileprivate func drawBar(_ a_ctx: CGContext, withRect a_rect: CGRect, andColor a_clr: QJColor, lit a_fLit: Bool) {
        // Is the bar lit?
        if a_fLit {
            // Are we doing radial gradient fills?
            if litEffect {
                // Yes, set up to draw the bar as a radial gradient
                let num_locations: size_t = 2
                let locations: [CGFloat] = [0.0, 0.5]
                var aComponents = [CGFloat]()
                let clr: CGColor = a_clr.cgColor
                // Set up color components from passed QJColor object
                if clr.numberOfComponents == 4 {
                    let ci = CIColor(color: a_clr)
                    #if os(iOS) || os(tvOS)
                        aComponents.append(ci.red)
                        aComponents.append(ci.green)
                        aComponents.append(ci.blue)
                        aComponents.append(ci.alpha)
                    #elseif os(macOS)
                        aComponents.append(ci?.red ?? 1.0)
                        aComponents.append(ci?.green ?? 1.0)
                        aComponents.append(ci?.blue ?? 1.0)
                        aComponents.append(ci?.alpha ?? 0.5)
                    #endif
                    // Calculate dark color of gradient
                    aComponents.append(aComponents[0] - ((aComponents[0] > 0.3) ? 0.3 : 0.0))
                    aComponents.append(aComponents[1] - ((aComponents[1] > 0.3) ? 0.3 : 0.0))
                    aComponents.append(aComponents[2] - ((aComponents[2] > 0.3) ? 0.3 : 0.0))
                    aComponents.append(aComponents[3])
                }

                // Calculate radius needed
                let width: CGFloat = a_rect.width
                let height: CGFloat = a_rect.height
                let radius: CGFloat = sqrt(width * width + height * height)

                // Draw the gradient inside the provided rectangle
                let myColorspace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
                let myGradient: CGGradient = CGGradient(colorSpace: myColorspace, colorComponents: aComponents, locations: locations, count: num_locations)!
                let myStartPoint = CGPoint(x: a_rect.midX, y: a_rect.midY)
                a_ctx.drawRadialGradient(myGradient, startCenter: myStartPoint, startRadius: 0.0, endCenter: myStartPoint, endRadius: radius, options: [])
            }
            else {
                // No, solid fill
                a_ctx.setFillColor(a_clr.cgColor)
                a_ctx.fill(a_rect)
            }
        }
        else {
            // No, draw the bar as background color overlayed with a mostly
            // ... transparent version of the passed color
            let fillClr: CGColor = a_clr.cgColor.copy(alpha: 0.2)!
            #if os(iOS) || os(tvOS)
                a_ctx.setFillColor(backgroundColor!.cgColor)
            #elseif os(macOS)
                a_ctx.setFillColor(layer!.backgroundColor!)
            #endif

            a_ctx.fill(a_rect)
            a_ctx.setFillColor(fillClr)
            a_ctx.fill(a_rect)
        }
    }
}
