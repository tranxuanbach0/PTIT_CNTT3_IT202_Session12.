      
-- Tạo cơ sở dữ liệu và các bảng

create database social_network;
use social_network;

-- Bảng users
create table users (
    user_id int auto_increment primary key,
    username varchar(50) unique not null,
    password varchar(255) not null,
    email varchar(100) unique not null,
    created_at datetime default current_timestamp
);

-- Bảng posts
create table posts (
    post_id int auto_increment primary key,
    user_id int not null,
    content text not null,
    created_at datetime default current_timestamp,
    foreign key (user_id) references users(user_id)
);

-- Bảng comments
create table comments (
    comment_id int auto_increment primary key,
    post_id int not null,
    user_id int not null,
    content text not null,
    created_at datetime default current_timestamp,
    foreign key (post_id) references posts(post_id),
    foreign key (user_id) references users(user_id)
);

-- Bảng friends
create table friends (
    user_id int not null,
    friend_id int not null,
    status varchar(20) default 'pending',
    primary key (user_id, friend_id),
    foreign key (user_id) references users(user_id),
    foreign key (friend_id) references users(user_id),
    check (status in ('pending', 'accepted'))
);

-- Bảng likes
create table likes (
    user_id int not null,
    post_id int not null,
    primary key (user_id, post_id),
    foreign key (user_id) references users(user_id),
    foreign key (post_id) references posts(post_id)
);

-- Mức độ trung bình

-- Bài 1: Quản lý người dùng
-- Thêm người dùng mới
insert into users (username, password, email) 
values 
    ('john_doe', 'hashed_password_1', 'john@example.com'),
    ('jane_smith', 'hashed_password_2', 'jane@example.com'),
    ('bob_wilson', 'hashed_password_3', 'bob@example.com');

-- Hiển thị danh sách người dùng
select * from users;

-- Bài 2: View thông tin công khai
create view vw_public_users as
select user_id, username, created_at
from users;

-- Sử dụng view
select * from vw_public_users;

-- So sánh với select trực tiếp
select user_id, username, created_at from users;

-- Bài 3: Tạo index cho tìm kiếm
create index idx_username on users(username);

-- Tìm user theo username
explain select * from users where username = 'john_doe';

-- Mức độ khá

-- Bài 4: Stored procedure tạo bài viết
delimiter //

create procedure sp_create_post(in p_user_id int, in p_content text)
begin
    -- Kiểm tra user có tồn tại không
    if exists (select 1 from users where user_id = p_user_id) then
        insert into posts (user_id, content) values (p_user_id, p_content);
        select `Đăng bài thành công` `Message`;
    else
        select `Người dùng không tồn tại` `Message`;
    end if;
end //

delimiter ;

-- Gọi procedure
call sp_create_post(1, 'Đây là bài viết mới từ procedure!!');

-- Bài 5: View news feed
create view vw_recent_posts as
select p.post_id, u.username, p.content, p.created_at
from posts p
join users u on p.user_id = u.user_id
where p.created_at >= now() - interval 7 day
order by p.created_at desc;

-- Sử dụng view
select * from vw_recent_posts;

-- Bài 6: Tối ưu truy vấn bài viết
-- Tạo index đơn
create index idx_post_user on posts(user_id);

-- Tạo composite index (ưu tiên user_id, sau đó sắp xếp theo created_at)
create index idx_user_created on posts(user_id, created_at);

-- Composite index (user_id, created_at) đóng vai trò rất quan trọng vì:

-- 1. user_id là điều kiện lọc chính trong mệnh đề where
--    -> giúp hệ quản trị cơ sở dữ liệu nhanh chóng xác định
--       các bài viết thuộc về một người dùng cụ thể

-- 2. created_at được đặt sau user_id trong index
--    -> dữ liệu trong index đã được sắp xếp sẵn theo thời gian
--    -> phù hợp trực tiếp với order by created_at desc

-- 3. nhờ composite index (user_id, created_at)
--    -> mysql có thể vừa lọc (where user_id = ?)
--    -> vừa sắp xếp (order by created_at desc)
--    mà không cần thực hiện filesort

-- 4. điều này giúp:
--    + giảm số dòng phải quét
--    + giảm chi phí sắp xếp
--    + tăng hiệu năng khi bảng posts có số lượng bản ghi lớn

-- 5. composite index đặc biệt hiệu quả cho các chức năng phổ biến
--    như xem bài viết cá nhân, news feed, phân trang bài viết

-- Truy vấn tận dụng composite index
select * from posts 
where user_id = 1 
order by created_at desc;

-- Bài 7: Procedure thống kê bài viết
delimiter //

create procedure sp_count_posts(in p_user_id int, out p_total int)
begin
    select count(*) into p_total 
    from posts 
    where user_id = p_user_id;
end //

delimiter ;

-- Gọi procedure
set @total_posts = 0;
call sp_count_posts(1, @total_posts);
select @total_posts `Total posts`;

-- Mức độ giỏi

-- Bài 8: View with check option
-- VD1
-- Giả sử ta muốn quản lý user có email đuôi @gmail.com
create view vw_gmail_users as
select user_id, username, email, password
from users
where email like '%@gmail.com'
with check option;

-- Thử insert dữ liệu hợp lệ qua view
insert into vw_gmail_users (username, password, email) 
values ('test_view_ok', '123', 'test@gmail.com');

-- VD2
-- Giả sử thêm cột is_active vào users
alter table users add column is_active boolean default true;

-- Cập nhật dữ liệu mẫu
update users set is_active = true where user_id = 1;
update users set is_active = false where user_id = 2;

create view vw_active_users as
select * from users where is_active = true
with check option;

-- Insert / update thông qua view
-- Thành công
insert into vw_active_users (username, password, email, is_active) values ('user3', 'pass3', 'user3@example.com', true);

-- Bài 9: Procedure kết bạn
delimiter //

create procedure sp_add_friend(in p_user_id int, in p_friend_id int)
begin
    if p_user_id = p_friend_id then
        select `Không thể kết bạn với chính mình` `Message`;
    else
        insert into friends (user_id, friend_id, status) 
        values (p_user_id, p_friend_id, 'pending');
        select `Lời mời kết bạn đã được gửi` `Message`;
    end if;
end //

delimiter ;

-- Gọi procedure
call sp_add_friend(1, 2);

-- Bài 10: Procedure gợi ý bạn bè
delimiter //

create procedure sp_suggest_friends(in p_user_id int, inout p_limit int)
begin
    -- Khai báo biến
    declare v_counter int default 0;
    
    -- Tạo bảng tạm để lưu kết quả gợi ý
    drop temporary table if exists tempsuggestions;
    create temporary table tempsuggestions (
        suggested_user_id int,
        suggested_username varchar(50)
    );

    -- Insert các user không phải là bạn và không phải chính mình vào bảng tạm
    insert into tempsuggestions
    select user_id, username
    from users
    where user_id != p_user_id
      and user_id not in (
          select friend_id from friends where user_id = p_user_id
          union
          select user_id from friends where friend_id = p_user_id
      )
    limit p_limit;
    
    -- Trả về kết quả
    select * from tempsuggestions;
end //

delimiter ;

-- Gọi thử
set @limit_val = 5;
call sp_suggest_friends(1, @limit_val);

-- Bài 11: View bài viết hàng đầu
create view vw_top_posts as
select p.post_id, p.content, count(l.user_id) `Like count`, u.username
from posts p
left join likes l on p.post_id = l.post_id
join users u on p.user_id = u.user_id
group by p.post_id, p.content, u.username
order by `Like count` desc
limit 5;

-- Tạo index cho likes
create index idx_post_likes on likes(post_id);

-- Truy vấn view
select * from vw_top_posts;

-- Mức độ xuất sắc

-- Bài 12: Quản lý bình luận
-- 1. Procedure thêm bình luận
delimiter //

create procedure sp_add_comment(in p_user_id int, in p_post_id int, in p_content text)
begin
    declare user_exists int;
    declare post_exists int;

    -- Kiểm tra user
    select count(*) into user_exists from users where user_id = p_user_id;
    -- Kiểm tra post
    select count(*) into post_exists from posts where post_id = p_post_id;

    if user_exists > 0 and post_exists > 0 then
        insert into comments (user_id, post_id, content) 
        values (p_user_id, p_post_id, p_content);
        select `Bình luận thành công` `Status`;
    else
        select `User hoặc Post không tồn tại` `Status`;
    end if;
end //

delimiter ;

-- Gọi thử
call sp_add_comment(2, 1, 'Bài viết hay quá!');

-- 2. View hiển thị bình luận
create view vw_post_comments as
select c.comment_id, p.post_id, u.username, c.content, c.created_at
from comments c
join users u on c.user_id = u.user_id
join posts p on c.post_id = p.post_id;

select * from vw_post_comments;

-- Bài 13: Quản lý lượt thích
delimiter //

create procedure sp_like_post(in p_user_id int, in p_post_id int)
begin
    declare already_liked int;
    
    -- Kiểm tra đã like chưa
    select count(*) into already_liked 
    from likes 
    where user_id = p_user_id and post_id = p_post_id;
    
    if already_liked > 0 then
        select `Bạn đã thích bài viết này rồi` `Message`;
    else
        insert into likes (user_id, post_id) values (p_user_id, p_post_id);
        select `Đã thích bài viết` `Message`;
    end if;
end //

delimiter ;

-- Gọi thử
-- User 2 like Post 1
call sp_like_post(2, 1);
-- Thử like lại lần nữa
call sp_like_post(2, 1);

-- 2. View thống kê
create view vw_post_likes as
select post_id, count(user_id) `Like count`
from likes
group by post_id;

select * from vw_post_likes;

-- Bài 14: Tìm kiếm nâng cao
delimiter //

create procedure sp_search_social(in p_option int, in p_keyword varchar(100))
begin
    -- Option 1: Tìm người dùng
    if p_option = 1 then
        select user_id, username, email 
        from users 
        where username like concat('%', p_keyword, '%');
        
    -- Option 2: Tìm bài viết
    elseif p_option = 2 then
        select post_id, content, created_at 
        from posts 
        where content like concat('%', p_keyword, '%');
        
    -- Option khác: Báo lỗi
    else
        select `Lỗi: Option không hợp lệ (1: User, 2: Post)` `Message`;
    end if;
end //

delimiter ;

-- Thêm dữ liệu mẫu bổ sung cho testing
-- Thêm người dùng có username chứa "an"
insert into users (username, password, email) 
values 
    ('an_nguyen', 'pass123', 'an@example.com'),
    ('anh_tran', 'pass456', 'anh@example.com'),
    ('andrew_smith', 'pass789', 'andrew@example.com'),
    ('mary_jane', 'pass101', 'mary@example.com'),
    ('peter_parker', 'pass202', 'peter@example.com'),
    ('david_brown', 'pass303', 'david@example.com');

-- Thêm bài viết với nội dung chứa "database"
insert into posts (user_id, content) 
values
	(4, 'Hôm nay tôi đang học về cơ sở dữ liệu database'),
	(5, 'MySQL là hệ quản trị cơ sở dữ liệu rất phổ biến'),
	(6, 'SQL và database rất quan trọng trong phát triển web'),
	(4, 'Chia sẻ kiến thức về relational database'),
	(5, 'Làm việc với database cần hiểu về indexing'),
	(6, 'Database normalization giúp tối ưu hóa dữ liệu');

-- Thêm bài viết bình thường khác
insert into posts (user_id, content)
values
	(1, 'Chào mừng mọi người đến với mạng xã hội của chúng tôi'),
	(2, 'Hôm nay thời tiết thật đẹp'),
	(3, 'Đang làm dự án về social network với MySQL'),
	(1, 'Practice makes perfect'),
	(2, 'Học SQL thật thú vị'),
	(3, 'Stored procedure giúp tái sử dụng code');

-- Thêm lượt thích
call sp_like_post(2, 1);
call sp_like_post(3, 1);
call sp_like_post(4, 1);
call sp_like_post(5, 1);  -- Post 1 có 4 likes
call sp_like_post(1, 2);
call sp_like_post(3, 2);
call sp_like_post(6, 2);  -- Post 2 có 3 likes
call sp_like_post(4, 3);
call sp_like_post(5, 3);  -- Post 3 có 2 likes
call sp_like_post(6, 4);  -- Post 4 có 1 like
call sp_like_post(2, 5);
call sp_like_post(3, 5);  -- Post 5 có 2 likes

-- Thêm bạn bè (accept một số, pending một số)
insert into friends (user_id, friend_id, status) values
(1, 4, 'accepted'),
(1, 5, 'accepted'),
(2, 3, 'accepted'),
(2, 6, 'accepted'),
(3, 4, 'accepted'),
(4, 5, 'pending'),
(5, 6, 'pending'),
(1, 6, 'accepted');

-- Cập nhật status is_active cho user mới
update users set is_active = true where user_id in (4, 5, 6);

-- Gọi thử nghiệm theo yêu cầu đề bài
-- 1. Tìm người dùng có username chứa từ "an"
call sp_search_social(1, 'an');

-- 2. Tìm bài viết có nội dung chứa từ "database" (hoặc từ có trong data mẫu)
call sp_search_social(2, 'database');

    