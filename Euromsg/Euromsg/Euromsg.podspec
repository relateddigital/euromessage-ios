Pod::Spec.new do |s|
s.name              = 'Euromsg'
s.version           = '2.0'
s.summary           = 'Euromsg'
s.homepage          = 'https://bitbucket.org/arafasapps/euromsg_ios.git'
s.ios.deployment_target = '8.0'
s.platform = :ios, '8.0'
s.license           = {
:type => 'MIT',
:file => 'LICENSE'
}
s.author            = {
'YOURNAME' => 'Muhammed ARAFA'
}
s.source            = {
:git => 'https://bitbucket.org/arafasapps/euromsg_ios.git',
:tag => "#{s.version}" }
s.framework = "UIKit"
s.source_files      = 'Euromsg*' , 'Classes/*', 'Resource/*'
s.requires_arc      = true
end
