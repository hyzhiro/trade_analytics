# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_11_16_130703) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "number"
    t.string "name"
    t.string "currency"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "statements", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "uploaded_at"
    t.integer "closed_pl"
    t.integer "balance"
    t.datetime "raw_generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_statements_on_account_id"
  end

  create_table "trades", force: :cascade do |t|
    t.bigint "statement_id", null: false
    t.bigint "account_id", null: false
    t.string "ticket", null: false
    t.datetime "open_time"
    t.string "trade_type"
    t.decimal "size", precision: 12, scale: 2
    t.string "item"
    t.decimal "open_price", precision: 20, scale: 6
    t.decimal "sl", precision: 20, scale: 6
    t.decimal "tp", precision: 20, scale: 6
    t.datetime "close_time"
    t.decimal "close_price", precision: 20, scale: 6
    t.integer "commission"
    t.integer "taxes"
    t.integer "swap"
    t.integer "profit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "ticket"], name: "index_trades_on_account_id_and_ticket", unique: true
    t.index ["account_id"], name: "index_trades_on_account_id"
    t.index ["statement_id"], name: "index_trades_on_statement_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "statements", "accounts"
  add_foreign_key "trades", "accounts"
  add_foreign_key "trades", "statements"
end
