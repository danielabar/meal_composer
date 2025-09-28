-- superuser for local dev in case we need to disable triggers for fast testing
create role meal_composer with CREATEDB SUPERUSER login password 'meal_composer';
