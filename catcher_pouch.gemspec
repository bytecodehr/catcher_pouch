# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'catcher_pouch'
  spec.version       = '0.1.0'
  spec.authors       = ['Bytecode Agency']
  spec.email         = ['dev@bytecodeagency.com']

  spec.summary       = 'Email template preview and editor for Rails admin panels'
  spec.description   = 'A mountable Rails engine that discovers your mailers, previews emails ' \
                        'with sample data, and lets you edit ERB templates live from your admin panel.'
  spec.homepage      = 'https://github.com/vedranmarcetic/catcher_pouch'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  spec.files = Dir[
    'lib/**/*',
    'app/**/*',
    'config/**/*',
    'LICENSE.txt',
    'README.md'
  ]

  spec.add_dependency 'rails', '>= 7.0'
end
