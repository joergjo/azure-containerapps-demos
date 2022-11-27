CREATE TABLE
  public.todo (
    id bigserial PRIMARY KEY ,
    description varchar(255) NULL,
    details varchar(255) NULL,
    done boolean NOT NULL
  );