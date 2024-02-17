Pod::Spec.new do |s|
  s.name         = "MarqueeLabel"
  s.version      = "4.5.0"
  s.summary      = "A drop-in replacement for UILabel, which automatically adds a scrolling marquee effect when needed."
  s.homepage     = "https://github.com/cbpowell/MarqueeLabel"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = "Charles Powell"
  s.source       = { :git => "https://github.com/cbpowell/MarqueeLabel.git", :tag => s.version.to_s }
  s.frameworks   = 'UIKit', 'QuartzCore'
  s.requires_arc = true
  s.source_files = 'Sources/*.swift'
  s.resource_bundles = {'MarqueeLabel' => ['Sources/*.xcprivacy']}
  s.ios.deployment_target = '12.0'
  s.tvos.deployment_target = '12.0'
  s.visionos.deployment_target = '1.0'
  s.swift_version = '5.0'
end
