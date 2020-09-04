Pod::Spec.new do |s|

s.name                  = 'CJJBlockHook'
s.version               = '1.0.2'
s.license               = { :type => 'MIT'}
s.summary               = 'CJJBlockHook make the thing that hook the block easier.'
s.description           = 'hook the block'
s.homepage              = 'https://github.com/JimmyCJJ/CJJBlockHook'
s.authors               = { 'JimmyCJJ' => '403327747@qq.com' }
s.social_media_url      = 'https://www.jianshu.com/u/fd9922e50c1a'
s.ios.deployment_target = '9.0'
s.source                = { :git => 'https://github.com/JimmyCJJ/CJJBlockHook.git', :tag => s.version  }
s.requires_arc = true
s.source_files = 'CJJBlockHook/CJJBlockHook/*.{h,m,c,s}'
s.pod_target_xcconfig = { 'VALID_ARCHS' => 'arm64 armv7 armv7s x86_64' }

end
