require 'spec_helper'

describe RLS::Statements do
  subject do
    Class.new(ActiveRecord::Migration[7.2]) { extend RLS::Statements }
  end

  let(:statements) { [] }

  def trim_sql sql
    sql.gsub(/\s+/, ' ').gsub(/\( /, '').gsub(/ \)/, '')
  end

  before do
    allow(subject.connection).to receive(:execute) do |statement|
      statements.concat trim_sql(statement).split(/\s*;\s*/)
      nil
    end

    allow(RLS::Railtie.config.rls_rails).to receive(:policy_dir).and_return 'spec/data/db/policies'
  end

  describe '#enable_rls' do
    pending 'Need to add examples'
  end

  describe '#disable_rls' do
    pending 'Need to add examples'
  end

  describe '#create_policy' do
    it 'enables RLS on the table' do
      subject.create_policy :users
      expect(statements).to include 'ALTER TABLE users ENABLE ROW LEVEL SECURITY, FORCE ROW LEVEL SECURITY'
    end

    it 'enables RLS with NO FORCE ROW LEVEL SECURITY if called with force: false' do
      subject.create_policy :users, force: false
      expect(statements).to include 'ALTER TABLE users ENABLE ROW LEVEL SECURITY, NO FORCE ROW LEVEL SECURITY'
    end

    it 'creates a policy from a file' do
      subject.create_policy :users
      expect(statements).to include 'CREATE POLICY my_policy ON users FOR all USING (id = current_user_id())'
    end

    context 'reverting' do
      it 'drops the policy' do
        subject.revert { subject.create_policy :users }
        expect(statements).to include 'DROP POLICY IF EXISTS my_policy ON users'
      end

      it 'drops the policy if called with force: false' do
        subject.revert { subject.create_policy :users, force: false }
        expect(statements).to include 'DROP POLICY IF EXISTS my_policy ON users'
      end

      pending 'disables RLS on the table' do
        subject.revert { subject.create_policy :users }
        expect(statements).to include 'ALTER TABLE users DISABLE ROW LEVEL SECURITY, NO FORCE ROW LEVEL SECURITY'
      end
    end
  end

  describe '#drop_policy' do
    pending 'Need to add examples'
  end

  describe '#update_policy' do
    pending 'Need to add examples'
  end

  describe '#change_policy_force' do
    context 'true' do
      it 'sets FORCE ROW LEVEL SECURITY' do
        subject.change_policy_force :users, true
        expect(statements).to include 'ALTER TABLE users FORCE ROW LEVEL SECURITY'
      end

      context 'reverting' do
        it 'sets NO FORCE ROW LEVEL SECURITY' do
          subject.revert { subject.change_policy_force :users, true }
          expect(statements).to include 'ALTER TABLE users NO FORCE ROW LEVEL SECURITY'
        end
      end
    end

    context 'false' do
      it 'sets NO FORCE ROW LEVEL SECURITY' do
        subject.change_policy_force :users, false
        expect(statements).to include 'ALTER TABLE users NO FORCE ROW LEVEL SECURITY'
      end

      context 'reverting' do
        it 'sets FORCE ROW LEVEL SECURITY' do
          subject.revert { subject.change_policy_force :users, false }
          expect(statements).to include 'ALTER TABLE users FORCE ROW LEVEL SECURITY'
        end
      end
    end
  end
end
