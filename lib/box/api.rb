require 'box/api/exceptions'

require 'httmultiparty'
require 'multi_json'

module Box
  # A wrapper and interface to the Box api. Please visit the Box developers
  # site for a full explaination of what each of the Box api methods
  # expect and perform.
  # TODO: Link to the site.

  class Api
    # an extension of HTTParty, adding multi-part upload support
    include HTTMultiParty

    # @return [String] The base url of the box api.
    attr_accessor :base_url

    # @return [String] The old url of the box api.
    attr_accessor :old_url

    #debug_output

    # Create a new API object using the given parameters.
    #
    # @note Chances are that if the Box api is updated or moves location,
    #       this class will no longer work. However, the option to change
    #       the defaults still remains.
    #
    # @param [String, Api] api_key The api key for your application. You can
    #        request one on the Box developer website at
    #        {http://www.box.net/developers/services}. If an {Api} instance
    #        is passed instead, its key is used.
    #
    # @param [String] url the url of the Box api.
    #
    def initialize(key, url = 'https://api.box.com')
      @api_key = key

      @default_params = { :api_key => key } # add the api_key
      @default_headers = { 'Authorization' => "BoxAuth api_key=#{ key }" }

      @base_url = "#{ url }/2.0" # set the base of the request url
      @old_url = "#{ url }/1.0" # logins still use v1
    end

    # Make a normal REST request.
    #
    # @param [String] expected the normal status expected to be returned.
    #        If the actual status does not match, an exception is thrown.
    # @param [Hash] options The parameters that wish to be passed in the
    #        request. These should coorespond to the api specifications,
    #        and will be passed along with the api key and auth token.
    #
    # @return [Hash] A parsed version of the XML response.
    #
    def query(method, *args)
      temp = args.pop if args.last.is_a?(Hash)
      temp ||= Hash.new

      url = [ @base_url, *args ].join("/")

      query = temp.delete(:query)
      headers = temp.delete(:headers) || Hash.new
      body = MultiJson.encode(temp) unless temp.empty?

      params = Hash.new
      params[:headers] = @default_headers.merge(headers)
      params[:query] = query if query
      params[:body] = body if body

      response = self.class.send(method.to_sym, url, params)
      raise response.inspect unless response.success?

      response
    end

    def query_old(*args)
      params = @default_params
      params = params.merge(args.pop) if args.last.is_a?(Hash)

      url = [ @old_url, 'rest', *args ].join("/")

      result = self.class.get(url, :query => params)
      result['response']
    end

    # Request a ticket for authorization
    def get_ticket
      query_old(:action => :get_ticket)
    end

    # Request an auth token given a ticket.
    #
    # @param [String] ticket the ticket to use.
    def get_auth_token(ticket)
      query_old(:action => :get_auth_token, :ticket => ticket)
    end

    # Add the auth token to every request.
    #
    # @param [String] auth_token The auth token to add to every request.
    def set_auth_token(auth_token)
      @auth_token = auth_token

      if auth_token
        @default_params[:auth_token] = auth_token
        @default_headers['Authorization'] = "BoxAuth api_key=#{ @api_key }&auth_token=#{ auth_token }"
      else
        @default_params.delete(:auth_token)
        @default_headers['Authorization'] = "BoxAuth api_key=#{ @api_key }"
      end
    end

    # Request the user be logged out.
    def logout
      query_old(:action => :logout)
    end

    # Register a new user.
    #
    # @param [String] email The email address to use.
    # @param [String] password The password to use.
    def register_new_user(email, password)
      query_old(:action => :register_new_user, :login => email, :password => password)
    end

    # Verify a registration email.
    #
    # @param [String] email The email address to check.
    def verify_registration_email(email)
      query_old(:action => :verify_registration_email, :login => email)
    end

    # Get the user's account info.
    def get_account_info
      query_old(:action => :get_account_info)
    end

    # VALID
    def get_file_info(file_id)
      query(:get, :files, file_id)
    end

    # VALID
    def update_file_info(file_id, info = Hash.new)
      query(:put, :files, file_id, info)
    end

    # VALID
    def delete_file(file_id, etag)
      query(:delete, :files, file_id, :headers => { 'If-Match' => etag || "" })
    end

    # VALID
    def upload_file(parent_id, file)
      query(:post, :files, :content, :query => { :file => file, :folder_id => parent_id })
    end

    # VALID
    def upload_version(file_id, file, old_etag, new_name = nil)
      query(:post, :files, file_id, :content, :query => { :file => file, :name => new_name }, :headers => { 'If-Match' => old_etag || "" })
    end

    # VALID
    def get_file_versions(file_id)
      query(:get, :files, file_id, :versions)
    end

    # VALID
    def download_file(file_id)
      query(:get, :files, file_id, :content)
    end

    # VALID
    def add_comment(file_id, message)
      query(:post, :files, file_id, :comments, :message => message)
    end

    # VALID
    def update_comment(comment_id, message)
      query(:put, :comments, comment_id, :message => message)
    end

    # VALID
    def delete_comment(comment_id)
      query(:delete, :comments, comment_id)
    end

    # VALID
    def get_comment_info(comment_id)
      query(:get, :comments, comment_id)
    end

    # VALID
    def share_file(file_id, params)
      query(:put, :files, file_id, :shared_link => params)
    end

    # VALID
    def copy_file(file_id, new_parent_id, new_name = nil)
      query(:post, :files, file_id, :copy, :parent => { :id => new_parent_id }, :name => new_name)
    end

    # VALID
    def create_folder(parent_id, name)
      query(:post, :folders, :parent => { :id => parent_id }, :name => name)
    end

    # VALID
    def get_folder_info(folder_id)
      query(:get, :folders, folder_id)
    end

    # VALID
    def update_folder_info(folder_id, params = Hash.new)
      params[:parent] = { :id => params[:parent] } if params[:parent]
      query(:put, :folders, folder_id, params)
    end

    # VALID
    def delete_folder(folder_id, recursive = false)
      query(:delete, :folders, folder_id, :query => { :recursive => recursive })
    end

    # VALID
    def copy_folder(folder_id, new_parent_id, new_name = nil)
      query(:post, :folders, folder_id, :copy, :parent => { :id => new_parent_id }, :name => new_name)
    end

    # VALID
    def share_folder(folder_id, params = Hash.new)
      query(:put, :folders, folder_id, :shared_link => params)
    end

=begin
    # Get the entire tree of a given folder.
    #
    # @param [String] folder_id The id of the folder to use.
    # @param [Array] args The arguments to pass along to get_account_tree.
    #
    # @note This function can take a long time for large folders.
    # @todo Use zip compression to save bandwidth.
    #
    # TODO: document the possible arguments.
    def get_account_tree(folder_id, *args)
      query(:get, [ :folders, folder_id ])
    end

    # Create a new folder.
    #
    # @param [String] parent_id The id of the parent folder to use.
    # @param [String] name The name of the newly created folder.
    # @param [Integer] shared The shared state of the new folder.
    def create_folder(parent_id, name, share = 0)
      query(:post, [ :folders, parent_id ], :name => name)
    end

    # Move the item to a new destination.
    #
    # @param ["file", "folder"] target The type of item.
    # @param [String] target_id The id of the item to move.
    # @param [String] destination_id The id of the parent to move to.
    def move(target, target_id, destination_id)
    end

    # Copy the the item to a new destination.
    #
    # @note The api currently only supports copying files.
    #
    # @param [String] target_id The id of the item to copy.
    # @param [String] destination_id The id of the parent to copy to.
    def copy(file_id, destination_id)
      query(:post, [ :files, file_id, :copy ], :destination_id => destination_id)
    end

    # Rename the item.
    #
    # @param ["file", "folder"] target The type of item.
    # @param [String] target_id The id of the item to rename.
    # @param [String] new_name The new name to be used.
    def rename(target, target_id, new_name)
    end

    # Delete the item.
    #
    # @param [String] file_id The id of the item to delete.
    def file_delete(file_id)
      query(:delete, [ :files, file_id ]
    end

    # Get the file info.
    #
    # @param [String] file_id The file id to get info for.
    def file_info(file_id)
      query(:get, [ :files, file_id ])
    end

    # Set the item description.
    #
    # @param ["file", "folder"] target The type of item.
    # @param [String] target_id The id of the item to describe.
    # @param [String] description The description to use.
    def set_description(target, target_id, description)
    end

    # Download the file to the given path.
    #
    # @note You cannot download folders.
    #
    # @param [String] file_id The file id to download.
    # @param [Optional, String] version The version of the file to download.
    def download(file_id, version = nil)
      query_download([ file_id, version ])
    end

    # Upload the file to the specified folder.
    #
    # @param [String, File or UploadIO] path Upload the file at the given path, or a File or UploadIO object..
    # @param [String] folder_id The folder id of the parent folder to use.
    # @param [Optional, Boolean] new_copy Upload a new copy instead of overwriting.
    def upload(path, folder_id, new_copy = false)
      path = ::File.new(path) unless path.is_a?(::UploadIO) or path.is_a?(::File)

      # We need to delete new_copy from the args if it is null or false.
      # This is because of a bug with the API that considers any value as 'true'
      options = { :file => path, :new_copy => new_copy }
      options.delete(:new_copy) unless new_copy

      query_upload('upload', folder_id, 'upload_ok', options)
    end

    # Overwrite the given file with a new one.
    #
    # @param [String, File or UploadIO] path (see #upload)
    # @param [String] file_id Replace the file with this id.
    # @param [Optional, String] name Use a new name as well.
    def overwrite(path, file_id, name = nil)
      path = ::File.new(path) unless path.is_a?(::UploadIO) or path.is_a?(::File)
      query_upload('overwrite', file_id, 'upload_ok', :file => path, :file_name => name)
    end

    # Upload a new copy of the given file.
    #
    # @param [String] path (see #upload)
    # @param [String] file_id The id of the file to copy.
    # @param [Optional, String] name Use a new name as well.
    # TODO: Verfiy this does what I think it does
    def new_copy(path, file_id, name = nil)
      query_upload('new_copy', file_id, 'upload_ok', :file => ::File.new(path), :new_file_name => name)
    end

    # Gets the comments posted on the given item.
    #
    # @param ["file"] target The type of item.
    # @param [String] target_id The id of the item to get.
    def get_comments(target, target_id)
      query_rest('get_comments_ok', :action => :get_comments, :target => target, :target_id => target_id)
    end

    # Adds a new comment to the given item.
    #
    # @param ["file"] target The type of item.
    # @param [String] target_id The id of the item to add to.
    # @param [String] message The message to use.
    def add_comment(target, target_id, message)
      query_rest('add_comment_ok', :action => :add_comment, :target => target, :target_id => target_id, :message => message)
    end

    # Deletes a given comment.
    #
    # @param [String] comment_id The id of the comment to delete.
    def delete_comment(comment_id)
      query_rest('delete_comment_ok', :action => :delete_comment, :target_id => comment_id)
    end

    # Request the HTML embed code for a file.
    #
    # @param [String] id The id of the file to use.
    # @param [Hash] options The properties for the generated preview code.
    #        See File#embed_code for a more detailed list of options.
    def file_embed(id, options = Hash.new)
      query_rest('s_create_file_embed', :action => :create_file_embed, :file_id => id, :params => options)
    end

    # Share an item publically, making it accessible via a share link.
    #
    # @param [String] target The type of item.
    # @param [String] target_id The id of the item to share.
    # @param [Hash] options Extra options related to notifications. Please
    #        read the developer documentation for more details.
    def share_public(target, target_id, options = Hash.new)
      query_rest('share_ok', { :action => :public_share, :target => target, :target_id => target_id, :password => "", :message => "", :emails => [ "" ] }.merge(options))
    end

    # Share an item privately, making it accessible only via email.
    #
    # @param [String] target The type of item.
    # @param [String] target_id The id of the item to share.
    # @param [Array] emails The email addresses of the individuals to share with.
    # @param [Hash] options Extra options related to notifications. Please
    #        read the developer documentation for more details.
    #
    def share_private(target, target_id, emails, options = Hash.new)
      query_rest('private_share_ok', { :action => :private_share, :target => target, :target_id => target_id, :emails => emails, :message => "", :notify => "" }.merge(options))
    end

    # Stop sharing an item publically.
    #
    # @param [String] target The type of item.
    # @param [String] target_id The id of the item to unshare.
    def unshare_public(target, target_id)
      query_rest('unshare_ok', :action => :public_unshare, :target => target, :target_id => target_id)
    end
=end
  end
end
