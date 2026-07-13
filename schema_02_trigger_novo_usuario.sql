-- =====================================================================
-- SGE — Addendum: cria automaticamente uma linha em `perfis` quando um
-- novo usuário é criado em Authentication (Supabase Auth).
-- Rode depois de aplicar schema.sql.
-- =====================================================================

create or replace function public.lidar_novo_usuario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfis (id, nome, papel)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nome', split_part(new.email, '@', 1)),
    'usuario'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.lidar_novo_usuario();

-- A partir de agora: crie o usuário em Authentication → Users, e a linha em
-- `perfis` aparece sozinha como 'usuario'. Para promover a admin:
--   update perfis set papel = 'admin' where id = '<uuid do usuário>';
