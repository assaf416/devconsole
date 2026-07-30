# encoding: utf-8

בהינתן('שהמשתמש פותח את דף הפרויקטים') do
  get '/projects'
  follow_redirect! if last_response.redirect?
end

בהינתן('שהמשתמש בעמוד הפרויקטים') do
  get '/projects'
  follow_redirect! if last_response.redirect?
end

אז('הדף מכיל לפחות פרויקט אחד') do
  expect(last_response.body).to include('פרויקט')
end

כאשר('הוא שומר פרויקט חדש עם השם {string}') do |project_name|
  post '/projects', {
    name: project_name,
    github_url: 'https://github.com/test/project',
    staging_url: 'https://staging.example.com',
    description: 'פרויקט בדיקה'
  }
  follow_redirect!
end

אז('הפרויקט צריך להשמר בבסיס הנתונים') do
  expect(last_response.body).to include('פרויקט בדיקה')
end

אז('הדף צריך להתעדכן עם הפרויקט החדש') do
  expect(last_response.body).to include('פרויקט בדיקה')
  expect(last_response.status).to eq(200)
end

בהינתן('שיש פרויקט קיים ברשימה') do
  @projects = app_db.execute('SELECT * FROM projects LIMIT 1')
  @project = @projects.first
  expect(@project).not_to be_nil
  get '/projects?edit_id=' + @project['id'].to_s
end

כאשר('המשתמש עורך אותו וגם משנה את השם') do
  new_name = @project['name'] + ' - מעודכן'
  post "/projects/#{@project['id']}", {
    id: @project['id'],
    name: new_name,
    github_url: @project['github_url'],
    staging_url: @project['staging_url'],
    description: @project['description']
  }
  follow_redirect!
end

אז('השינוי צריך להשמר בבסיס הנתונים') do
  updated_project = app_db.execute('SELECT * FROM projects WHERE id = ?', @project['id']).first
  expect(updated_project['name']).to include('מעודכן')
end

כאשר('המשתמש מבקש למחוק אותו') do
  post "/projects/#{@project['id']}/delete"
  follow_redirect!
end

אז('הפרויקט צריך להימחק מבסיס הנתונים') do
  deleted_project = app_db.execute('SELECT * FROM projects WHERE id = ?', @project['id']).first
  expect(deleted_project).to be_nil
end

אז('הרשימה צריכה להתעדכן') do
  expect(last_response.status).to eq(200)
  expect(last_response.body).not_to include(@project['name'])
end
