#ifndef __BASE_SAMPLES_RIGID_BODY_STATE_HH
#define __BASE_SAMPLES_RIGID_BODY_STATE_HH

#ifdef __GCCXML__
#define EIGEN_DONT_VECTORIZE
#endif

#ifdef __orogen
#error "this header cannot be used in orogen-parsed code. Use wrappers/samples/rigid_body_state.h and wrappers::samples::RigidBodyState instead"
#endif

#include <base/pose.h>
#include <base/time.h>

#include <Eigen/Core>
#include <Eigen/LU>

namespace base { namespace samples {
    struct RigidBodyState
    {
        base::Time time;

	/** name of the source reference frame */
	std::string sourceFrame;

	/** name of the target reference frame */
	std::string targetFrame;

        /** Position in m, world fixed frame of reference (East-North-Up) */
        Position   position;
	/** Covariance matrix of the position
	 */
        base::Matrix3d cov_position;

        /** Orientation as a body->world transformation */
        Orientation orientation;
        /** Covariance matrix of the orientation as an axis/angle manifold in
         * body coordinates
	 */
        base::Matrix3d cov_orientation;

        /** Velocity in m/s with respect to world fixed frame, in body fixed
         * frame (Right-Front-Up) */
        base::Vector3d velocity;
	/** Covariance of the velocity 
	 */
        base::Matrix3d cov_velocity;

        /** Angular Velocity as an axis-angle representation in body fixed frame
         * (Right-Front-Up)
         *
         * The direction of the vector is the axis, its length the speed */
        base::Vector3d angular_velocity;
        /** Covariance of the angular velocity
	 */
        base::Matrix3d cov_angular_velocity;

	void setTransform(const Eigen::Affine3d& transform)
	{
	    orientation = Eigen::Quaterniond( transform.linear() );
	    position = transform.translation();
	}

	 Eigen::Affine3d getTransform() const 
	 {
	    Eigen::Affine3d ret;
	    ret.setIdentity();
	    ret.rotate(this->orientation);
	    ret.translation() = this->position;
	    return ret;
	 }

	void setPose(const base::Pose& pose)
	{
	    orientation = pose.orientation;
	    position = pose.position;
	}

	base::Pose getPose() const
	{
	    return base::Pose( position, orientation );
	}

        double getYaw() const
        {
            return base::getYaw(orientation);
        }
	
	operator Eigen::Affine3d() const
	{
	    Eigen::Affine3d ret;
	    ret.setIdentity();
	    ret.rotate(this->orientation);
	    ret.translation() = this->position;
	    return ret;
	}

        static RigidBodyState invalid() {
            RigidBodyState result;
            result.invalidate();
            return result;
        }
	
        /** For backward compatibility only. Use invalidate() */
        void initSane() {
            invalidate();
        }

        /** Initializes the rigid body state with arbitrary values for the
         * position, velocity, orientation and angular velocity, and with
         * infinite covariance matrices
         */
	void invalidate() {
	    invalidateOrientation();
	    invalidatePosition();
	    invalidateVelocity();
	    invalidateAngularVelocity();
	    
	    position.setZero();
	    velocity.setZero();
	    orientation = Eigen::Quaterniond::Identity();
	    angular_velocity.setZero();
	}
	
	bool hasValidPosition() const {
	    return !isinf(cov_position(0,0)) && !isinf(cov_position(1,1)) && !isinf(cov_position(2,2));
	}
        bool hasValidPosition(int idx) const {
            return !isinf(cov_position(idx, idx));
        }
	
	bool hasValidOrientation() const {
	    return !isinf(cov_orientation(0,0)) && !isinf(cov_orientation(1,1)) && !isinf(cov_orientation(2,2));
	}
        bool hasValidOrientation(int idx) const {
            return !isinf(cov_orientation(idx, idx));
        }
	
	bool hasValidVelocity() const {
	    return !isinf(cov_velocity(0,0)) && !isinf(cov_velocity(1,1)) && !isinf(cov_velocity(2,2));
	}
        bool hasValidVelocity(int idx) const {
            return !isinf(cov_velocity(idx, idx));
        }
	
	bool hasValidRotationVelocity() const {
	    return !isinf(cov_angular_velocity(0,0)) && !isinf(cov_angular_velocity(1,1)) && !isinf(cov_angular_velocity(2,2));
	}
        bool hasValidRotationVelocity(int idx) const {
            return !isinf(cov_angular_velocity(idx, idx));
        }
	
	void invalidatePosition() {
	    cov_position = Eigen::Matrix3d::Identity();
	    cov_position *= INFINITY;	  
	}
	
	void invalidateOrientation() {
	    cov_orientation = Eigen::Matrix3d::Identity();
	    cov_orientation *= INFINITY;
	}
	
	void invalidateVelocity() {
	    cov_velocity = Eigen::Matrix3d::Identity();
	    cov_velocity *= INFINITY;	  
	}
	
	void invalidateAngularVelocity() {
	    cov_angular_velocity = Eigen::Matrix3d::Identity();
	    cov_angular_velocity *= INFINITY;
	}
    };
}}

#endif

