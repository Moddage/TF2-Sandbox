/*
 *this include file is for matrix/linear algebra support for sourcemod
 */
#if defined _matrixmath_included
#endinput
#endif
#define _matrixmath_included

public const Float:ZERO_VECTOR[3] = {0.0, 0.0, 0.0};

enum matrix3x4_t{

	Float:row0[4],
	Float:row1[4],
	Float:row2[4]

};

stock matrix3x4_tFromArray(const Float:array[3][4], matrix[matrix3x4_t]){

	matrix[row0][0] = array[0][0];
	matrix[row0][1] = array[0][1];
	matrix[row0][2] = array[0][2];
	matrix[row0][3] = array[0][3];
	
	matrix[row1][0] = array[1][0];
	matrix[row1][1] = array[1][1];
	matrix[row1][2] = array[1][2];
	matrix[row1][3] = array[1][3];

	matrix[row2][0] = array[2][0];
	matrix[row2][1] = array[2][1];
	matrix[row2][2] = array[2][2];
	matrix[row2][3] = array[2][3];

}

stock matrix3x4_tFromVector(Float:fwd[3], Float:right[3], Float:up[3], Float:origin[3], matrix[matrix3x4_t]){

	matrix[row0][0] = fwd[0];
	matrix[row0][1] = right[0];
	matrix[row0][2] = up[0];
	matrix[row0][3] = origin[0];
	
	matrix[row1][0] = fwd[1];
	matrix[row1][1] = right[1];
	matrix[row1][2] = up[1];
	matrix[row1][3] = origin[1];
	
	matrix[row2][0] = fwd[2];
	matrix[row2][1] = right[2];
	matrix[row2][2] = up[2];
	matrix[row2][3] = origin[2];

}

stock matrix3x4FromAngles(Float:angle[3], Float:origin[3], matrix[matrix3x4_t]){

	decl Float:fwd[3], Float:right[3], Float:up[3];
	
	GetAngleVectors(angle, fwd, right, up);
	
	NormalizeVector(fwd, fwd);
	NormalizeVector(right, right);
	NormalizeVector(up, up);
	
	matrix3x4_tFromVector(fwd, right, up, origin, matrix);

}

stock matrix3x4FromAnglesNoOrigin(Float:angle[3], matrix[matrix3x4_t]){

	decl Float:fwd[3], Float:right[3], Float:up[3];
	
	new Float:origin[3] = {0.0, 0.0, 0.0};
	
	GetAngleVectors(angle, fwd, right, up);
	
	matrix3x4_tFromVector(fwd, right, up, origin, matrix);

}

stock TransformAnglesToWorldSpace(Float:inputangle[3], Float:outputangle[3], parentmatrix[matrix3x4_t]){

	decl angtoparent[matrix3x4_t], angtoworld[matrix3x4_t];
	
	matrix3x4FromAnglesNoOrigin(inputangle, angtoparent);
	
	ConcatTransforms( parentmatrix, angtoparent, angtoworld);
	
	MatrixAngles(angtoworld, outputangle);
	
}

stock ConcatTransforms(const in1[matrix3x4_t], const in2[matrix3x4_t], out[matrix3x4_t]){
	
	out[row0][0] = in1[row0][0] * in2[row0][0] + in1[row0][1] * in2[row1][0] + in1[row0][2] * in2[row2][0];
	out[row0][1] = in1[row0][0] * in2[row0][1] + in1[row0][1] * in2[row1][1] + in1[row0][2] * in2[row2][1];
	out[row0][2] = in1[row0][0] * in2[row0][2] + in1[row0][1] * in2[row1][2] + in1[row0][2] * in2[row2][2];
	out[row0][3] = in1[row0][0] * in2[row0][3] + in1[row0][1] * in2[row1][3] + in1[row0][2] * in2[row2][3] + in1[row0][3];
	
	out[row1][0] = in1[row1][0] * in2[row0][0] + in1[row1][1] * in2[row1][0] + in1[row1][2] * in2[row2][0];
	out[row1][1] = in1[row1][0] * in2[row0][1] + in1[row1][1] * in2[row1][1] + in1[row1][2] * in2[row2][1];
	out[row1][2] = in1[row1][0] * in2[row0][2] + in1[row1][1] * in2[row1][2] + in1[row1][2] * in2[row2][2];
	out[row1][3] = in1[row1][0] * in2[row0][3] + in1[row1][1] * in2[row1][3] + in1[row1][2] * in2[row2][3] + in1[row1][3];
	
	out[row2][0] = in1[row2][0] * in2[row0][0] + in1[row2][1] * in2[row1][0] + in1[row2][2] * in2[row2][0];
	out[row2][1] = in1[row2][0] * in2[row0][1] + in1[row2][1] * in2[row1][1] + in1[row2][2] * in2[row2][1];
	out[row2][2] = in1[row2][0] * in2[row0][2] + in1[row2][1] * in2[row1][2] + in1[row2][2] * in2[row2][2];
	out[row2][3] = in1[row2][0] * in2[row0][3] + in1[row2][1] * in2[row1][3] + in1[row2][2] * in2[row2][3] + in1[row2][3];
	
}

stock MatrixAngles(angtoworld[matrix3x4_t], Float:outputangle[3]){

	decl Float:fwd[3], Float:right[3], Float:up[3];
	
	fwd[0] = angtoworld[row0][0];
	fwd[1] = angtoworld[row1][0];
	fwd[2] = angtoworld[row2][0];
	right[0] = angtoworld[row0][1];
	right[1] = angtoworld[row1][1];
	right[2] = angtoworld[row2][1];
	up[0] = 0.0;
	up[1] = 0.0;
	up[2] = angtoworld[row2][2];
	
	new Float:xyDist = SquareRoot(fwd[0] * fwd[0] + fwd[1] * fwd[1]);
	
	if ( xyDist > 0.001 ){
	
		// (yaw)	y = ATAN( forward.y, forward.x );		-- in our space, forward is the X axis
		outputangle[1] = RadToDeg( ArcTangent2( fwd[1], fwd[0] ) );
		// (pitch)	x = ATAN( -forward.z, sqrt(forward.x*forward.x+forward.y*forward.y) );
		outputangle[0] = RadToDeg( ArcTangent2( fwd[2] * -1, xyDist ) );
		// (roll)	z = ATAN( left.z, up.z );
		outputangle[2] = RadToDeg( ArcTangent2( right[2], up[2] ) );
		
	}else{// forward is mostly Z, gimbal lock-
	
		// (yaw)	y = ATAN( -left.x, left.y );			-- forward is mostly z, so use right for yaw
		outputangle[1] = RadToDeg( ArcTangent2( right[0]  * -1, right[1] ) );
		// (pitch)	x = ATAN( -forward.z, sqrt(forward.x*forward.x+forward.y*forward.y) );
		outputangle[0] = RadToDeg( ArcTangent2( fwd[2]  * -1, xyDist ) );
		// Assume no roll in this case as one degree of freedom has been lost (i.e. yaw == roll)
		outputangle[2] = 0.0;
		
	}

}

stock MatrixFwdAngle(angtoworld[matrix3x4_t], Float:outputangle[3]){

	decl Float:fwd[3], Float:right[3], Float:up[3];
	
	fwd[0] = angtoworld[row0][0];
	fwd[1] = angtoworld[row1][0];
	fwd[2] = angtoworld[row2][0];
	
	right[0] = angtoworld[row0][1];
	right[1] = angtoworld[row1][1];
	right[2] = angtoworld[row2][1];
	
	up[0] = angtoworld[row0][2];
	up[1] = angtoworld[row1][2];
	up[2] = angtoworld[row2][2];
	
	GetVectorAngles(fwd, outputangle);
	
}

stock TransformAnglesToLocalSpace(Float:angle[3], Float:out[3], parentMatrix[matrix3x4_t]){

	decl angToWorld[matrix3x4_t], worldToParent[matrix3x4_t], localMatrix[matrix3x4_t];
	
	MatrixInvert( parentMatrix, worldToParent );
	
	matrix3x4FromAnglesNoOrigin( angle, angToWorld );
	
	ConcatTransforms( worldToParent, angToWorld, localMatrix );
	
	MatrixAngles( localMatrix, out );

}

stock MatrixInvert(in[matrix3x4_t], out[matrix3x4_t]){

	out[row0][0] = in[row0][0];
	out[row0][1] = in[row1][0];
	out[row0][2] = in[row2][0];

	out[row1][0] = in[row0][1];
	out[row1][1] = in[row1][1];
	out[row1][2] = in[row2][1];

	out[row2][0] = in[row0][2];
	out[row2][1] = in[row1][2];
	out[row2][2] = in[row2][2];
	
	decl Float:tmp[3], Float:outrow0[3], Float:outrow1[3], Float:outrow2[3];
	tmp[0] = in[row0][3];
	tmp[1] = in[row1][3];
	tmp[2] = in[row2][3];
	
	outrow0[0] = out[row0][0];
	outrow0[1] = out[row0][1];
	outrow0[2] = out[row0][2];
	
	outrow1[0] = out[row1][0];
	outrow1[1] = out[row1][1];
	outrow1[2] = out[row1][2];
	
	outrow2[0] = out[row2][0];
	outrow2[1] = out[row2][1];
	outrow2[2] = out[row2][2];
	
	out[row0][3] = -GetVectorDotProduct(tmp, outrow0);
	out[row1][3] = -GetVectorDotProduct(tmp, outrow1);
	out[row2][3] = -GetVectorDotProduct(tmp, outrow2);
	
}

stock clampangle(Float:angle[3]){

	if(angle[0] > 180.0){
				
		angle[0] = angle[0] - 360.0;
	
	}else if(angle[0] < -180.0){
	
		angle[0] = angle[0] + 360.0;
	
	}
	if(angle[1] > 180.0){
	
		angle[1] = angle[1] - 360.0;
	
	}else if(angle[1] < -180.0){
	
		angle[1] = angle[1] + 360.0;
	
	}
	if(angle[2] > 180.0){
	
		angle[2] = angle[2] - 360.0;
	
	}else if(angle[2] < -180.0){
	
		angle[2] = angle[2] + 360.0;
	
	}

}


stock ZeroVector(Float:vector[3]){

	vector[0] = 0.0;
	vector[1] = 0.0;
	vector[2] = 0.0;

}

stock CopyVector(const Float:in[3], Float:out[3]){

	out[0] = in[0];
	out[1] = in[1];
	out[2] = in[2];

}