# ActsAsAdminable

module ActsAsAdminable
  DEFAULT_STRING = 'Click to Edit'

  module Helper
    def self.included(base)
      base.send :alias_method_chain, :content_tag, :adminable
    end    
    def content_tag_with_adminable(name, content_or_options_with_block = nil, options = nil, escape = true, &block)
      if block_given?
        return content_tag_without_adminable(name, content_or_options_with_block, options, escape, &block)
      elsif options.is_a?(Hash) && (!options[:key].blank? || !options["key"].blank?)
        
        key = (options.delete(:key) || options.delete("key")).gsub(/\W+/,'')
        object_id = options[:id] || options["id"]
        if object_id.blank? 
          options[:id] = key
          object_id = key
        end
        
        db_contents = ActiveRecord::Base.connection.select_one("SELECT * FROM adminable_text WHERE content_key = '#{key}'")
        
        db_value = db_contents.is_a?(Hash) ? 
                        (db_contents["value"] || content_or_options_with_block || ActsAsAdminable::DEFAULT_STRING) : 
                        (content_or_options_with_block || ActsAsAdminable::DEFAULT_STRING)
                        
        html_contents = markdown(auto_link(db_value)).gsub(/^<p>(.*)<\/p>$/,'\1') || content_or_options_with_block

        if true #TODO: is_admin?
          
          options[:onmouseover]='window.temp_style_background=this.style.backgroundColor; this.style.backgroundColor = "#FFD";'
          options[:onmouseout]='this.style.backgroundColor=window.temp_style_background; window.temp_style_background = undefined;'
          options[:onclick]="s=this; f=$('#{key}_form'); t=$('#{key}_field'); p=s.cumulativeOffset(); d=s.getDimensions(); t.style.width=d.width+'px'; t.style.height=d.height+'px'; window.style_display=s.style.display; s.style.visibility='hidden'; f.style.display='block'; f.style.position='absolute'; f.style.left=s[0]; f.style.top=s[1];"
          options[:style] = (options[:style] || options['style']).to_s + '; cursor: pointer'
          form_remote_tag :url => '/admin/save_adminable_text', :html => {:style => 'display: none;', :id => key+'_form'} do
            hidden_field_tag(:content_key, key)     +
            hidden_field_tag(:object_id, object_id) +
            text_field_tag(:value, (db_contents.nil? ? '' : db_contents["value"]),  :id => key+'_field') +
            submit_tag('Save Text', :style => 'position: absolute; right: 0px; bottom: -25px;') +
            button_to_function('Cancel',"$('#{key}_form').style.display='none'; $('#{key}').style.visibility='visible'", :style => 'position: absolute; right: 100px; bottom: -25px;')
          end
          
          return content_tag_without_adminable(name, html_contents, options, escape)

        else
          return content_tag_without_adminable(name, html_contents, options, escape)
        end

      else
        return content_tag_without_adminable(name, content_or_options_with_block, options, escape)
      end
    end
  end
  
  
  
  module MapperExtensions
    def self.included(base)
      base.send :alias_method_chain, :initialize, :adminable
    end
    def initialize_with_adminable(set)
      #we have to add ours FIRST, otherwise the final line of the regular routes.rb is usually a catchall that would intercept OUR route
      set.add_route('/admin/save_adminable_text',{:controller => 'acts_as_adminable/adminable', :action => 'save_text'})
      initialize_without_adminable(set)
    end
  end
  
  
  
  # A custom controller that we'll use for routing trickiness.
  class AdminableController < ActionController::Base
    def save_text
      #TODO: make this check the ADMIN flag before trusting input
      if request.post? && !params[:content_key].blank?
        key = params[:content_key].gsub(/\W+/,'')
        value = params[:value].gsub('"','\"')
        sql = %Q{INSERT INTO adminable_text(content_key, data_type, value) VALUES ('#{key}', 'text', \"#{value}\") ON DUPLICATE KEY UPDATE value = \"#{value}\"}
        ActiveRecord::Base.connection.execute(sql) unless key.blank?  
        render :update do |page|
          page.replace_html key, markdown(auto_link(params[:value]))[3..-5]
          page << "$('#{key}_form').style.display='none'"
          page << "$('#{key}').style.visibility='visible'"
        end
      else
        render :nothing => true
      end
    end
  end  
end