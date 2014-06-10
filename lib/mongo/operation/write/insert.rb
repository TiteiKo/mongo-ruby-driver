# Copyright (C) 2009-2014 MongoDB, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mongo

  module Operation

    module Write

      # A MongoDB insert operation.
      # If a server with version >= 2.5.5 is selected by the
      # client, a write command operation will be created and sent instead.
      # See Mongo::Operation::Write::WriteCommand::Insert
      #
      # @since 3.0.0
      class Insert
        include Executable

        # Initialize the insert operation.
        #
        # @example Initialize an insert operation.
        #   include Mongo
        #   include Operation
        #   Write::Insert.new({ :documents     => [{ :foo => 1 }],
        #                       :db_name       => 'test',
        #                       :coll_name     => 'test_coll',
        #                       :write_concern => { 'w' => 2 }
        #                     })
        #
        # @param [ Hash ] spec The specifications for the insert.
        # @param [ Hash ] context The context for executing this operation.
        #
        # @option spec :documents [ Array ] The documents to insert.
        # @option spec :db_name [ String ] The name of the database on which
        #   the query should be run.
        # @option spec :coll_name [ String ] The name of the collection on which
        #   the query should be run.
        # @option spec :write_concern [ Hash ] The write concern for this operation.
        # @option spec :ordered [ true, false ] Whether the operations should be
        #   executed in order.
        # @option spec :opts [Hash] Options for the command, if it ends up being a
        #   write command.
        #
        # @option context :server [ Mongo::Server ] The server that the operation
        #   should be sent to.
        #
        # @since 3.0.0
        def initialize(spec, context = {})
          @spec       = spec
          @server     = context[:server]
        end

        # Execute the operation.
        # The client uses the context to get a server. If the server has
        # version < 2.5.5, an insert wire protocol operation is sent.
        # If the server version is >= 2.5.5, an insert write command operation is created
        # and sent to the server instead.
        #
        # @params [ Mongo::Client ] The client to use to get a server.
        #
        # @todo: Make sure this is indeed the client#with_context API
        # @return [ Array ] The operation results and server used.
        #
        # @since 3.0.0
        def execute(context)
          # @todo: change wire version to constant
          if context.wire_version >= 2
            op = WriteCommand::Delete.new(spec)
            op.execute(context)
          else
            documents.each do |d|
              context.with_connection do |connection|
                gle = write_concern.get_last_error
                connection.dispatch([message(d), gle])
              end
            end
          end
        end

        private

        # The write concern to use for this operation.
        #
        # @return [ Hash ] The write concern.
        #
        # @since 3.0.0
        def write_concern
          @spec[:write_concern]
        end

        # The documents to insert.
        #
        # @return [ Array ] The documents.
        #
        # @since 3.0.0
        def documents
          @spec[:documents]
        end

        # The primary server preference for the operation.
        #
        # @return [ Mongo::ServerPreference::Primary ] A primary server preference.
        #
        # @since 3.0.0
        def server_preference
          Mongo::ServerPreference.get(:primary)
        end

        # The wire protocol message for this insert operation.
        #
        # @return [ Mongo::Protocol::Insert ] Wire protocol message.
        #
        # @since 3.0.0
        def message(insert_spec = {})
          document = [insert_spec[:document]]
          insert_spec = insert_spec[:continue_on_error] == 0 ? { } : { :flags => [:continue_on_error] }
          Mongo::Protocol::Insert.new(db_name, coll_name, document, insert_spec)
        end
      end
    end
  end
end
