# ActsAsAdminable

module ActsAsAdminable
  DEFAULT_STRING = 'Click to Edit'

  module ActionControllerExtension
    def self.included(base)
      base.extend ClassMethods
    end
    module ClassMethods
      def acts_as_adminable(options = {})
        RAILS_DEFAULT_LOGGER.debug "Got here, options = #{options.inspect}"
        @is_adminable = options.has_key?(:if) ? options[:if].call : true
        self.class_eval "def is_adminable?; #{@is_adminable.to_s}; end"
      end
#      def is_adminable?
#        @is_adminable
#      end
    end
  end

  module Helper
    def self.included(base)
      base.send :alias_method_chain, :content_tag, :adminable
    end
    def is_adminable?
      controller.is_adminable?
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
                        
        html_contents = markdown(db_value).gsub(/^<p>(.*)<\/p>$/,'\1').gsub(/  /,'&nbsp;&nbsp;') || content_or_options_with_block

        if is_adminable?
          
          options[:onmouseover]='window.temp_style_background=this.style.backgroundColor; this.style.backgroundColor = "#FFD";'
          options[:onmouseout]='this.style.backgroundColor=window.temp_style_background; window.temp_style_background = undefined;'
          options[:onclick]="s=this; f=$('#{key}_form'); t=$('#{key}_field'); p=s.cumulativeOffset();  f.style.position='absolute'; f.style.left=p[0]+'px'; f.style.top=p[1]+'px'; d=s.getDimensions(); t.style.width=d.width+'px'; t.style.height=d.height+'px'; window.style_display=s.style.display; s.style.visibility='hidden'; f.style.display='block';"
          options[:style] = (options[:style] || options['style']).to_s + '; cursor: pointer'
          
          #which tags get edited by an INPUT, and which by a TEXTAREA
          if [:h1, :h2, :h3, :h4, :h5, :h6, :span, :b, :i, :u, :em, :strong].include?(name)
            text_input_html = text_field_tag(:value, (db_contents.nil? ? '' : db_contents["value"]),  :id => key+'_field')
          elsif [:div, :td, :th, :pre, :p, :li, :blockquote].include?(name)
            text_input_html = text_area_tag(:value, (db_contents.nil? ? '' : db_contents["value"]),  :id => key+'_field')
          else
            text_input_html = text_area_tag(:value, (db_contents.nil? ? '' : db_contents["value"]),  :id => key+'_field')
          end
          
          #For some reason, this block prints immediately.  So no need to concatenate with our return value or anything like that
          form_remote_tag :url => '/admin/save_adminable_text', :html => {:style => 'display: none;', :id => key+'_form'} do
            hidden_field_tag(:content_key, key)     +
            hidden_field_tag(:object_id, object_id) +
            text_input_html +
            submit_tag('Save Text', :style => 'position: absolute; right: 0px; bottom: -25px;') +
            button_to_function('Cancel',"$('#{key}_form').style.display='none'; $('#{key}').style.visibility='visible'", :style => 'position: absolute; right: 100px; bottom: -25px;')
          end

        end
        
        return content_tag_without_adminable(name, html_contents, options, escape)

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
          page.replace_html key, markdown(params[:value]).gsub(/^<p>(.*)<\/p>$/,'\1').gsub(/  /,'&nbsp;&nbsp;')
          page << "$('#{key}_form').style.display='none'"
          page << "$('#{key}').style.visibility='visible'"
        end
      else
        render :nothing => true
      end
    end
  end  
end