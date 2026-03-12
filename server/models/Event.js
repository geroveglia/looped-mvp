const mongoose = require('mongoose');

const EventSchema = new mongoose.Schema({
    name: { type: String, required: true },
    host_user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    organizer: { type: String, default: 'Looped' },
    description: { type: String },
    goal_steps: { type: Number, default: 10000 },
    
    // Time & Date
    starts_at: { type: Date, required: true },
    ends_at: { type: Date }, // Optional

    // Details
    genre: { 
        type: String, 
        enum: ['techno', 'house', 'reggaeton', 'trance', 'pop', 'hiphop', 'other'],
        required: true 
    },

    // Location
    venue_name: { type: String }, // Optional
    address: { type: String, required: true },
    city: { type: String, required: true },
    country: { type: String, required: true },
    location: {
        type: { type: String, enum: ['Point'], default: 'Point' },
        coordinates: { type: [Number], default: [0, 0] } // [long, lat]
    },
    geofence_radius: { type: Number, default: 500 }, // in meters

    // Visibility & Access
    visibility: { type: String, enum: ['public', 'private'], default: 'public' },
    invite_code: { type: String }, // Generated if private
    is_paid_public: { type: Boolean, default: false },
    
    icon: { type: String, default: '🎵' }, // Store emoji or url

    status: { type: String, enum: ['waiting', 'active', 'ended'], default: 'waiting' },
    created_at: { type: Date, default: Date.now }
});

EventSchema.index({ location: '2dsphere' }); // For future geofencing

module.exports = mongoose.model('Event', EventSchema);
