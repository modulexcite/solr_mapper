# Copyright 2010 The Skunkworx.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

Dir[File.join(File.dirname(__FILE__), 'solr_mapper', '*.rb')].each do |file|
  require file
end

require 'rest_client'
require 'builder'
require 'will_paginate'
require 'will_paginate/collection'
require 'active_support/inflector'
require 'active_support/hash_with_indifferent_access'

include ActiveSupport::Inflector

module SolrMapper
end
