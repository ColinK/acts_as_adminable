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
    end
  end

  module Helper
    def self.included(base)
      base.send :alias_method_chain, :content_tag, :adminable
    end
    def is_adminable?
      (controller.methods.include? "is_adminable?") ? controller.is_adminable? : false
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

          options[:onmouseover]='window.temp_style_background=this.style.backgroundColor; this.style.backgroundColor = "#CCE";'
          options[:onmouseout]='this.style.backgroundColor=window.temp_style_background; window.temp_style_background = undefined;'

          #this one is awesome in FF and Safari, but totally broken in IE (can't get width or position of inline elements)
          #options[:onclick]="s=this; f=$('#{key}_form'); t=$('#{key}_field'); p=s.cumulativeOffset();  f.style.position='absolute'; f.style.left=p[0]+'px'; f.style.top=p[1]+'px'; d=s.getDimensions(); t.style.width=d.width+'px'; t.style.height=d.height+'px'; window.style_display=s.style.display; s.style.visibility='hidden'; f.style.display='block';"

          #this one's less elegant; a modal AJAX popupin the center of the browser window
          options[:onclick]="f=$('#{key}_form'); v=document.viewport; o=v.getScrollOffsets(); h=v.getHeight(); w=v.getWidth(); f.style.left=o[0]+Math.round(w/3)+'px'; f.style.top=o[1]+Math.round(h/3)+'px'; f.style.width=Math.round(w/3)+'px'; f.style.height=Math.round(h/3)+'px'; f.style.display='block';"

          options[:style] = (options[:style] || options['style']).to_s + '; cursor: pointer'
          
          text_input_html = text_area_tag(:value, (db_contents.nil? ? '' : db_contents["value"]),  :size => '40x10', :id => key+'_field', :style => 'width: 100%; height: 85%;')
          
          #For some reason, this block prints immediately.  So no need to concatenate with our return value or anything like that
          form_remote_tag :url => '/admin/save_adminable_text', :html => {:style => 'display: none;', :id => key+'_form', :style => "position: absolute; z-index: 10; background-color: white; border: solid blue 2px; display: none; padding: 8px;"  } do
            hidden_field_tag(:content_key, key)     +
            hidden_field_tag(:object_id, object_id) +
            text_input_html +
            submit_tag('Save Text', :style => 'position: absolute; right: 10px; bottom: 10px; width: 80px;') +
            button_to_function('Cancel',"$('#{key}_form').style.display='none'; $('#{key}').style.visibility='visible'", :style => 'position: absolute; right: 100px; bottom: 10px; width: 80px;')
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
        end
      else
        render :nothing => true
      end
    end
  end  
end