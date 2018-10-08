require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
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
  @list = @lists[@list_id]
  erb :list
end

# render the edit list form
get '/lists/:list_id/edit' do
  @list_id = params['list_id'].to_i
  @list = @lists[@list_id]
  erb :edit_list
end

# edit a list by id
post '/lists/:list_id' do
  @list_id = params['list_id'].to_i
  @list = @lists[@list_id]
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
  @list = @lists[@list_id]

  if session['lists'].delete_at(@list_id)
    session['success'] = "Removed list `#{@list[:name]}`."
  else
    session['error'] = 'Unable to locate list.'
  end

  redirect '/lists'
end

# add a new todo to a list
post '/lists/:list_id/todos' do
  @list_id = params['list_id'].to_i
  @list = @lists[@list_id]
  todo_name = params['todo'].strip

  error = error_for_todo_name(todo_name)
  if error
    session['error'] = error
    erb :list
  else
    @list[:todos] << { name: todo_name, completed: false }
    session['success'] = "Added todo `#{todo_name}`."
    redirect "/lists/#{@list_id}"
  end
end
