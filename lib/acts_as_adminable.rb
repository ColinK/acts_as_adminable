# ActsAsAdminable

module ActsAsAdminable

  module Helper
    def self.included(base)
      base.send :alias_method_chain, :content_tag, :adminable
    end    
    def content_tag_with_adminable(name, content_or_options_with_block = nil, options = nil, escape = true, &block)
      if block_given?
        return content_tag_without_adminable(name, content_or_options_with_block, options, escape, &block)
      elsif options.is_a?(Hash) && (!options[:key].blank? || !options["key"].blank? || !options[:id].blank? || !options["id"].blank?)
        
        key = (options.delete(:key) || options.delete("key") || options[:id] || options["id"]).gsub(/\W+/,'')
        
        db_contents = ActiveRecord::Base.connection.select_one("SELECT * FROM adminable_text WHERE content_key = '#{key}'")
        html_contents = markdown(auto_link(db_contents["value"]))[3..-5] || content_or_options_with_block

        if true #TODO: is_admin?
          
          options[:onmouseover]='window.temp_style_background=this.style.backgroundColor; this.style.backgroundColor = "#FFD";'
          options[:onmouseout]='this.style.backgroundColor=window.temp_style_background; window.temp_style_background = undefined;'
          options[:onclick]="s=this; f=$('#{key}_form'); t=$('#{key}_field'); p=s.cumulativeOffset(); d=s.getDimensions(); window.style_display=s.style.display; s.style.visibility='hidden'; f.style.display='block'; f.style.position='absolute'; f.style.left=s[0]; f.style.top=s[1]; t.width=d.width; t.height=d.height;"

          form_remote_tag :url => '/admin/save_adminable_text', :html => {:style => 'display: none;', :id => key+'_form'} do
            hidden_field_tag :content_key, key
            text_field_tag :value, (db_contents.nil? ? '' : db_contents["value"]), :html => { :id => key+'_field'}
            submit_tag
          end + content_tag_without_adminable(name, html_contents, options, escape)

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
        sql = %Q{UPDATE adminable_text SET value = \"#{params[:value].gsub('"','\"')}\" WHERE content_key = '#{key}'}
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