require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'

  set :erb, :escape_html => true
end

# return an error message if the name is invalid; return nil if name is valid
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'The list name must be between 1 and 100 characters.'
  elsif @lists.any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

def error_for_todo_name(name)
  if !(1..100).cover? name.size
    'The todo name must be between 1 and 100 characters.'
  end
end

def load_list(index)
  list = @lists[index]
  if list && index
    list
  else
    session['error'] = 'The specified list was not found'
    redirect '/lists'
  end
end

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

helpers do
  def list_completed?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    'complete' if list_completed?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def sort_lists(lists, &block)
    completed_lists, uncompleted_lists =
      index_collection(lists).partition { |list, idx| list_completed?(list) }

    (uncompleted_lists + completed_lists).each(&block)
  end

  def sorted_todos(todos, &block)
    completed_todos, uncompleted_todos = todos.partition { |todo| todo[:completed] }
    (uncompleted_todos + completed_todos).each(&block)
  end
end

before do
  session['lists'] ||= []
  @lists = session['lists']
end

get '/' do
  redirect '/lists'
end

# view all lists
get '/lists' do
  erb :lists
end

# render the new list form
get '/lists/new' do
  erb :new_list
end

# create a new list
post '/lists' do
  @list_name = params['list_name'].strip

  error = error_for_list_name(@list_name)
  if error
    session['error'] = error
    erb :new_list
  else
    session['lists'] << { name: @list_name, todos: [] }
    session['success'] = "Created list `#{@list_name}`."
    redirect '/lists'
  end
end

# view a specific list by id
get '/lists/:list_id' do
  @list_id = params['list_id'].to_i
  @list = load_list(@list_id)
  erb :list
end

# render the edit list form
get '/lists/:list_id/edit' do
  @list_id = params['list_id'].to_i
  @list = load_list(@list_id)
  erb :edit_list
end

# edit a list by id
post '/lists/:list_id' do
  @list_id = params['list_id'].to_i
  @list = load_list(@list_id)
  list_name = params['list_name'].strip

  error = error_for_list_name(list_name)
  if error
    session['error'] = error
    erb :edit_list
  else
    @lists[@list_id][:name] = list_name
    session['success'] = 'The list has been updated.'
    redirect "/lists/#{@list_id}"
  end
end

# delete a list by id
post '/lists/:list_id/delete' do
  @list_id = params['list_id'].to_i
  @list = load_list(@list_id)

  @lists.delete_at(@list_id)
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    session['success'] = "Removed list `#{@list[:name]}`."
    redirect '/lists'
  end
end

# add a new todo to a list
post '/lists/:list_id/todos' do
  @list_id = params['list_id'].to_i
  @list = load_list(@list_id)
  todo_name = params['todo'].strip

  error = error_for_todo_name(todo_name)
  if error
    session['error'] = error
    erb :list
  else
    todo_id = next_todo_id(@list[:todos])
    @list[:todos] << { id: todo_id, name: todo_name, completed: false }
    session['success'] = "Added todo `#{todo_name}`."
    redirect "/lists/#{@list_id}"
  end
end

# delete a todo
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params['list_id'].to_i
  @list = load_list(@list_id)
  @todo_id = params['todo_id'].to_i
  @todo = @list[:todos].find { |todo| todo[:id] == @todo_id }

  @list[:todos].delete(@todo)
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    session['success'] = "Removed todo `#{@todo[:name]}`."
    redirect "/lists/#{@list_id}"
  end
end

# update the status of a todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params['list_id'].to_i
  @list = load_list(@list_id)
  @todo_id = params['todo_id'].to_i
  @todo = @list[:todos].find { |todo| todo[:id] == @todo_id }

  @todo[:completed] = params['completed'] == 'true'
  session['success'] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# mark all todos as complete for a list
post '/lists/:list_id/complete_all' do
  @list_id = params['list_id'].to_i
  @list = load_list(@list_id)

  @list[:todos].each { |todo| todo[:completed] = true }
  session['success'] = 'All todos have been completed.'
  redirect "/lists/#{@list_id}"
end
