﻿// <auto-generated />
using System;
using Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Infrastructure.Migrations
{
    [DbContext(typeof(MyDbContext))]
    [Migration("20250519111500_Migrations")]
    partial class Migrations
    {
        /// <inheritdoc />
        protected override void BuildTargetModel(ModelBuilder modelBuilder)
        {
#pragma warning disable 612, 618
            modelBuilder
                .HasAnnotation("ProductVersion", "9.0.0")
                .HasAnnotation("Relational:MaxIdentifierLength", 63);

            NpgsqlModelBuilderExtensions.UseIdentityByDefaultColumns(modelBuilder);

            modelBuilder.Entity("Domain.Entities.Guest", b =>
                {
                    b.Property<int>("Guestid")
                        .ValueGeneratedOnAdd()
                        .HasColumnType("integer")
                        .HasColumnName("guestid");

                    NpgsqlPropertyBuilderExtensions.UseIdentityByDefaultColumn(b.Property<int>("Guestid"));

                    b.Property<DateTime?>("Createdat")
                        .ValueGeneratedOnAdd()
                        .HasColumnType("timestamp without time zone")
                        .HasColumnName("createdat")
                        .HasDefaultValueSql("CURRENT_TIMESTAMP");

                    b.Property<string>("Email")
                        .IsRequired()
                        .HasMaxLength(150)
                        .HasColumnType("character varying(150)")
                        .HasColumnName("email");

                    b.Property<string>("Fullname")
                        .IsRequired()
                        .HasMaxLength(100)
                        .HasColumnType("character varying(100)")
                        .HasColumnName("fullname");

                    b.Property<string>("Phonenumber")
                        .HasMaxLength(15)
                        .HasColumnType("character varying(15)")
                        .HasColumnName("phonenumber");

                    b.HasKey("Guestid")
                        .HasName("guest_pkey");

                    b.HasIndex(new[] { "Email" }, "guest_email_key")
                        .IsUnique();

                    b.ToTable("guest", (string)null);
                });

            modelBuilder.Entity("Domain.Entities.Guestrole", b =>
                {
                    b.Property<int>("Roleid")
                        .ValueGeneratedOnAdd()
                        .HasColumnType("integer")
                        .HasColumnName("roleid");

                    NpgsqlPropertyBuilderExtensions.UseIdentityByDefaultColumn(b.Property<int>("Roleid"));

                    b.Property<string>("Description")
                        .HasColumnType("text")
                        .HasColumnName("description");

                    b.Property<string>("Rolename")
                        .IsRequired()
                        .HasMaxLength(50)
                        .HasColumnType("character varying(50)")
                        .HasColumnName("rolename");

                    b.HasKey("Roleid")
                        .HasName("guestrole_pkey");

                    b.HasIndex(new[] { "Rolename" }, "guestrole_rolename_key")
                        .IsUnique();

                    b.ToTable("guestrole", (string)null);
                });

            modelBuilder.Entity("Domain.Entities.Guestrolemapping", b =>
                {
                    b.Property<int>("Guestid")
                        .HasColumnType("integer")
                        .HasColumnName("guestid");

                    b.Property<int>("Roleid")
                        .HasColumnType("integer")
                        .HasColumnName("roleid");

                    b.Property<DateTime?>("Assignedat")
                        .ValueGeneratedOnAdd()
                        .HasColumnType("timestamp without time zone")
                        .HasColumnName("assignedat")
                        .HasDefaultValueSql("CURRENT_TIMESTAMP");

                    b.HasKey("Guestid", "Roleid")
                        .HasName("guestrolemapping_pkey");

                    b.HasIndex("Roleid");

                    b.ToTable("guestrolemapping", (string)null);
                });

            modelBuilder.Entity("Domain.Entities.Guestrolemapping", b =>
                {
                    b.HasOne("Domain.Entities.Guest", "Guest")
                        .WithMany("Guestrolemappings")
                        .HasForeignKey("Guestid")
                        .OnDelete(DeleteBehavior.Cascade)
                        .IsRequired()
                        .HasConstraintName("guestrolemapping_guestid_fkey");

                    b.HasOne("Domain.Entities.Guestrole", "Role")
                        .WithMany("Guestrolemappings")
                        .HasForeignKey("Roleid")
                        .OnDelete(DeleteBehavior.Cascade)
                        .IsRequired()
                        .HasConstraintName("guestrolemapping_roleid_fkey");

                    b.Navigation("Guest");

                    b.Navigation("Role");
                });

            modelBuilder.Entity("Domain.Entities.Guest", b =>
                {
                    b.Navigation("Guestrolemappings");
                });

            modelBuilder.Entity("Domain.Entities.Guestrole", b =>
                {
                    b.Navigation("Guestrolemappings");
                });
#pragma warning restore 612, 618
        }
    }
}
