Pod::Spec.new do |s|
s.name              = 'Euromsg'
s.version           = '2.0'
s.summary           = 'Euromsg'
s.homepage          = 'https://github.com/relateddigital/euromessage-ios.git'
s.ios.deployment_target = '8.0'
s.platform = :ios, '8.0'
s.license           = 'Related Digital'
s.author            = {
'YOURNAME' => 'Muhammed ARAFA'
}
s.source            = {
:git => 'https://github.com/relateddigital/euromessage-ios.git',
:tag => "#{s.version}" }
s.framework = "UIKit"
s.source_files      =  'Classes/*'
s.requires_arc      = true
end
