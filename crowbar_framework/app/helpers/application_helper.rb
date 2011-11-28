# Copyright 2011, Dell 
# 
# Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at 
# 
#  http://www.apache.org/licenses/LICENSE-2.0 
# 
# Unless required by applicable law or agreed to in writing, software 
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and 
# limitations under the License. 
# 
# Author: RobHirschfeld 
# 
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  # Is this a Rails 2-ism - csrf_meta_tag?
  # app/helpers/application_helper.rb
  def csrf_meta_tag
    if protect_against_forgery?
      out = %(<meta name="csrf-param" content="%s"/>\n)
      out << %(<meta name="csrf-token" content="%s"/>)
      out % [ Rack::Utils.escape_html(request_forgery_protection_token),
              Rack::Utils.escape_html(form_authenticity_token) ]
    end
  end
  
  def dl_item(term, definition, options={})
    unless definition.blank? && options[:show_if_blank] != true
      html  = "<dt>#{options[:escape_html] != false ? (h term) : (term)}</dt>"
      html += "<dd>#{options[:escape_html] != false ? (h definition) : (definition)}</dd>"
      raw html
    end
  end
  
  def column_class(current_column, total)
    if (current_column % total) == 0
      "first"
    elsif (current_column % total) == (total-1)
      "last"
    end
  end

  def hash_to_ul(hash)
    result = "<ul>"
    hash.each do |key,value|
      result << "<li>#{key}"
      if value.is_a?(Hash)
        result << hash_to_ul(value)
      else
        result << ": #{value}</li>"
      end
    end
    result << "</ul>"
  end

  def render_attributes(raw, proposal)
    if raw
      render :partial => 'barclamp/edit_attributes_raw'
    else
      begin
        render :partial => "barclamp/#{proposal.barclamp}/edit_attributes"
      rescue ActionView::MissingTemplate
        render :partial => 'barclamp/edit_attributes_raw'
      rescue Exception => e
        puts "Attribute Exception #{e.class}: #{e.message}"
        puts e.backtrace
        render :partial => 'barclamp/edit_attributes_raw'
      end
    end
  end

  def render_deployment(raw, proposal)
    if raw
      render :partial => 'barclamp/edit_deployment_raw'
    else
      begin
        render :partial => "barclamp/#{proposal.barclamp}/edit_deployment"
      rescue ActionView::MissingTemplate
        render :partial => 'barclamp/edit_deployment_raw'
      rescue 
        puts "Deployment Exception #{e.message}"
        puts e.backtrace
        render :partial => 'barclamp/edit_deployment_raw'
      end
    end
  end

  def instance_selector(bc, name, field, proposal)
    service = eval("#{bc.camelize}Service.new nil")
    options = service.list_active[1] | service.proposals[1]
    if options.empty?
      options = [["None", ""]]
    else
      options = options.map { |x| [x,x] }
    end

    def_val = proposal.raw_data['attributes'][proposal.barclamp][field] || ""

    select_tag name, options_for_select(options, def_val), :onchange => "update_value(#{field}, #{field}, 'string')"
  end

end
