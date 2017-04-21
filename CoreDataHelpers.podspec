Pod::Spec.new do |s|

  s.name         = "CoreDataHelpers"
  s.version      = "0.1.1"
  s.summary      = "CoreDataHelpers contain CoreData stack initialization and helper methods to work with requests"
  s.homepage     = "https://github.com/Streetmage/CoreDataHelpers"
  s.license      = "MIT"

  s.author = "Evgeny Kubrakov"

  s.ios.deployment_target  = '10.0'

  s.source       = { :git => "https://github.com/Streetmage/CoreDataHelpers.git", :tag => "0.1.1" }

  s.source_files  = "CoreDataHelpers/*.swift"

  s.framework  = "CoreData"

  s.requires_arc = true

end
