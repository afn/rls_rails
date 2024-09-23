require 'spec_helper'

RSpec.describe RLS do
  before(:each) do
    ActiveRecord::Base.connection.enable_query_cache!
  end

  def current_state
    result = ActiveRecord::Base.connection.execute <<-SQL
      SELECT current_setting('rls.tenant_id', TRUE) as tenant_id,
             current_setting('rls.user_id',   TRUE) as user_id,
             current_setting('rls.disable',   TRUE) as disable;
    SQL

    result.first.symbolize_keys
  end

  describe '.with' do
    context 'setting rls_disabled' do
      it 'sets the state within the block' do
        RLS.with(rls_disabled: true) do
          expect(current_state).to eq disable: 'TRUE', user_id: '', tenant_id: ''
        end
      end

      it 'resets the state after exiting the block' do
        RLS.with(rls_disabled: true) do
          # noop
        end

        expect(current_state).to eq disable: 'FALSE', user_id: '', tenant_id: ''
      end
    end

    context 'setting user_id and tenant_id' do
      it 'sets the values within the block' do
        RLS.with(user: User.new(id: 1), tenant: Tenant.new(id: 2)) do
          expect(current_state).to eq disable: 'FALSE', user_id: '1', tenant_id: '2'
        end
      end

      it 'resets the state after exiting the block' do
        RLS.with(user: User.new(id: 1), tenant: Tenant.new(id: 2)) do
          # noop
        end

        expect(current_state).to eq disable: 'FALSE', user_id: '', tenant_id: ''
      end
    end

    context 'nested calls' do
      it 'resets the state after each nested block exits' do
        RLS.with(user: User.new(id: 1)) do
          RLS.with(tenant: Tenant.new(id: 2)) do
            RLS.with(rls_disabled: true) do
              expect(current_state).to eq disable: 'TRUE', user_id: '', tenant_id: ''
            end
            expect(current_state).to eq disable: 'FALSE', user_id: '', tenant_id: '2'
          end
          expect(current_state).to eq disable: 'FALSE', user_id: '1', tenant_id: ''
        end
        expect(current_state).to eq disable: 'FALSE', user_id: '', tenant_id: ''
      end
    end

    context 'when an error is raised' do
      it 'propagates the error and resets the state' do
        expect do
          RLS.with(user: User.new(id: 1)) do
            raise 'an error'
          end
        end.to raise_error 'an error'

        expect(current_state).to eq disable: 'FALSE', user_id: '', tenant_id: ''
      end

      context 'within a transaction' do
        it 'resets the current state after the transaction is rolled back' do
          RLS.with(user: User.new(id: 1)) do
            ActiveRecord::Base.transaction do
              RLS.with(user: User.new(id: 2)) do
                expect do
                  ActiveRecord::Base.connection.execute 'select * from nonexistent_table'
                end.to raise_error ActiveRecord::StatementInvalid
              end
            end
            expect(current_state).to eq disable: 'FALSE', user_id: '1', tenant_id: ''
          end

          expect(current_state).to eq disable: 'FALSE', user_id: '', tenant_id: ''
        end

        it 'resets the current state after a savepoint is restored' do
          RLS.with(user: User.new(id: 1)) do
            ActiveRecord::Base.transaction do
              RLS.with(user: User.new(id: 2)) do
                ActiveRecord::Base.connection.create_savepoint 'savepoint1'
                expect do
                  RLS.with(user: User.new(id: 3)) do
                    ActiveRecord::Base.connection.execute 'select * from nonexistent_table'
                  end
                end.to raise_error ActiveRecord::StatementInvalid
                ActiveRecord::Base.connection.rollback_to_savepoint 'savepoint1'
                expect(current_state).to eq disable: 'FALSE', user_id: '2', tenant_id: ''
              end
            end
            expect(current_state).to eq disable: 'FALSE', user_id: '1', tenant_id: ''
          end

          expect(current_state).to eq disable: 'FALSE', user_id: '', tenant_id: ''
        end
      end
    end

    context 'with multiple database connections' do
      context 'connection already exists' do
        it 'propagates RLS state to other connections' do
          ActiveRecord::Base.connected_to(role: :secondary) do
            ActiveRecord::Base.connection.execute 'SELECT 1'
          end

          RLS.with(user: User.new(id: 1)) do
            ActiveRecord::Base.connected_to(role: :secondary) do
              expect(current_state).to eq disable: 'FALSE', user_id: '1', tenant_id: ''
            end

            expect(current_state).to eq disable: 'FALSE', user_id: '1', tenant_id: ''
          end
        end
      end

      context 'connection opened inside of RLS.with block' do
        it 'propagates RLS state to other connections' do
          RLS.with(user: User.new(id: 1)) do
            ActiveRecord::Base.connected_to(role: :secondary) do
              expect(current_state).to eq disable: 'FALSE', user_id: '1', tenant_id: ''
            end
            expect(current_state).to eq disable: 'FALSE', user_id: '1', tenant_id: ''
          end
        end
      end
    end

    context 'with multiple threads' do
      pending 'propagates RLS state to threads' do
        thread = nil
        input = Queue.new
        output = Queue.new

        RLS.with(user: User.new(id: 1)) do
          thread = Thread.new do
            input.pop
            output << current_state
            input.pop
            output << current_state
            input.pop
            output << current_state
          end
          thread.run

          input.push nil
          expect(output.pop).to eq disable: 'FALSE', user_id: '1', tenant_id: ''
          RLS.with(user: User.new(id: 2)) do
            expect(current_state).to eq disable: 'FALSE', user_id: '2', tenant_id: ''
            input.push nil
            expect(output.pop).to eq disable: 'FALSE', user_id: '1', tenant_id: ''
          end
        end

        expect(current_state).to eq disable: 'FALSE', user_id: '', tenant_id: ''
        input.push nil
        expect(output.pop).to eq disable: 'FALSE', user_id: '1', tenant_id: ''

        thread.join
      end
    end
  end
end
