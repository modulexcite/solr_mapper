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

module SolrMapper
  module SolrDocument
    module ClassMethods
      attr_accessor :has_many_relationships

      # handle a has one relationship. this document contains a foreign key to a doc in another index
      def has_one(target, opts = {})
        class_name, field_name, variable_name, id_field = determine_names(target, opts)

        class_eval do
          define_method field_name do
            val = instance_variable_get(variable_name)

            unless val
              id = instance_variable_get("@#{id_field}")
              val = Object::const_get(class_name).find(id) if id
            end

            val
          end

          define_method "#{field_name}=" do |val|
            instance_variable_set("@#{field_name}", val)
          end
        end
      end

      # handle a has one relationship. this document contains a foreign key to another index's documents
      def has_many(target, opts = {})
        class_name, field_name, variable_name, id_field = determine_names(target, opts)
        @@facet_field_name = field_name
        has_many_relationships[field_name.to_s] = id_field

        # add class method for loading relations via facets
        class << self
          define_method "#{@@facet_field_name}_facet" do |search|
            fk =  has_many_relationships[__method__.to_s.gsub(/_facet$/, '')]

            solr_results = raw_query(search, {'facet' => 'true', 'facet.field' => fk})
            klass = Object::const_get(classify(singularize(__method__.to_s.gsub(/_facet$/, ''))))
            results = {}

            solr_results['facet_counts']['facet_fields'][fk].each_slice(2).each do |pair|
              child = klass.find(pair[0])
              results[child] = pair[1] if child
            end

            results
          end
        end

        @@facet_field_name = nil

        # add a helper method that we'll use to hook arrays with manipulation logic we need
        class_eval do
          def relationize_array(array)
            class << array
              alias :super_push :push
              alias :super_delete :delete

              def << val
                val.save
                push val
                @owner.save()
              end

              def push val
                super_push val
                @owner.refresh_relation(instance_variable_get("@field_name"))
              end

              def destroy val
                val.destroy
                delete val
              end

              def delete val
                super_delete val
                @owner.refresh_relation(instance_variable_get("@field_name"))
              end
            end

            array
          end

          # define a getter for this relation
          define_method field_name do
            val = instance_variable_get(variable_name)

            unless val
              ids = instance_variable_get("@#{id_field}")
              val = []

              val.instance_variable_set("@owner", self)
              val.instance_variable_set("@field_name", field_name.to_s)

              unless ids
                instance_variable_set("@#{id_field}", [])
                ids = instance_variable_get("@#{id_field}")
              end

              ids.each do |id|
                val << Object::const_get(class_name).find(id)
              end

              # patch this array up so it does the callbacks we need
              relationize_array(val)

              instance_variable_set(variable_name, val)
            end

            val
          end

          # define a setter for this relation
          define_method "#{field_name}=" do |vals|
            ids = []

            if self.class.instance_variable_get('@solr_fields').include?(field_name)
              self.class.instance_variable_get('@solr_fields') << field_name
            end

            if vals
              vals.each do |obj|
                ids << obj._id
              end

              # if we didnt' create this array we'll have to patch it up to deal with our callbacks & patching
              relationize_array(vals) unless vals.respond_to?(:destroy)
            end

            instance_variable_set("@#{id_field}", ids)
            instance_variable_set("@#{field_name}", val)
          end
        end
      end

      # handle a belongs to relation. target index contains document with foreign keys to this document
      def belongs_to(target_name, opts = {})
        target_id_field_name = foreign_key(self.name)

        class_eval do
          # create getter for owner object
          define_method target_name do
            owner = instance_variable_get("@#{target_name}")

            unless owner
              # owner object hasn't been lazy loaded.  do so now.
              owner = Object::const_get(classify(target_name)).query(target_id_field_name => instance_variable_get("@_id"))[0]
              instance_variable_set("@#{target_name}", owner)
            end
            
            owner
          end

          # create setter for owner object
          define_method "#{target_name}=" do |val|
            instance_variable_set("@#{target_name}", val)
            val.instance_variable_set("@#{target_id_field_name}", instance_variable_get("@_id"))
            val.save()            
          end
        end
      end

      protected

      # figure out the names of properties and classes involved in the relation
      def determine_names(target, opts = {})
        class_name = opts[:class_name]
        class_name ||= classify(target)
        field_name = target
        variable_name = "@#{field_name}"
        id_field = opts[:foreign_key]
        id_field ||= "#{foreign_key(singularize(target))}"

        return class_name, field_name, variable_name, id_field
      end
    end

    # when the owner collection is modified this will be called sync the relation up
    def refresh_relation(field_name)
      ids = instance_variable_get("@#{self.class.has_many_relationships[field_name]}")
      ids.clear
        
      instance_variable_get("@#{field_name}").each do |child|
        ids << child._id
      end
    end
  end
end

