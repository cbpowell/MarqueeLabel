Pod::Spec.new do |s|
  s.name         = "MarqueeLabel-Swift"
  s.version      = "2.3.5"
  s.summary      = "A drop-in replacement for UILabel, which automatically adds a scrolling marquee effect when needed."
  s.homepage     = "https://github.com/cbpowell/MarqueeLabel"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Charles Powell" => "cbpowell@gmail.com" }
  s.source       = { :git => "https://github.com/cbpowell/MarqueeLabel-Swift.git", :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '9.0'
  s.source_files = 'Classes/*.{swift}'
  s.frameworks   = 'QuartzCore'
  s.requires_arc = true
end
