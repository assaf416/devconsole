# encoding: utf-8

בהינתן('שהמשתמש פותח את דף הבית') do
  get '/'
  follow_redirect!
end

אז('קוד התגובה הוא {int}') do |code|
  expect(last_response.status).to eq(code)
end

אז('הדף מכיל את הטקסט {string}') do |text|
  expect(last_response.body).to include(text)
end
